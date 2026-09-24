require "json"
require "net/http"
require "openssl"
require "uri"

module ActiveBilling
  module Providers
    # Stripe adapter (https://docs.stripe.com/api).
    #
    # Plans map to a Product plus a recurring Price. Prices are immutable, so a
    # price change creates a new Price and archives the previous one; the current
    # price id travels in `Result#raw["price_id"]` and comes back through
    # `ProviderReference#metadata`. Payments use hosted Checkout Sessions in
    # `payment` mode, whose `payment_status` drives the Charge state.
    #
    # Settings: `api_key` (required), `webhook_secret` (required for webhooks),
    # `success_url` / `cancel_url` (Checkout redirects), `webhook_tolerance` (seconds).
    class Stripe < Base # rubocop:disable Metrics/ClassLength
      BASE_URL = "https://api.stripe.com/v1".freeze
      WEBHOOK_TOLERANCE = 300

      INTERVALS = { "monthly" => "month", "yearly" => "year" }.freeze

      PAYMENT_STATUSES = {
        "unpaid" => "pending",
        "no_payment_required" => "paid",
        "paid" => "paid"
      }.freeze

      SESSION_STATUSES = {
        "expired" => "expired"
      }.freeze

      WEBHOOK_EVENTS = {
        "checkout.session.completed" => :payment_paid,
        "checkout.session.async_payment_succeeded" => :payment_paid,
        "checkout.session.async_payment_failed" => :payment_failed,
        "checkout.session.expired" => :payment_expired,
        "customer.subscription.created" => :subscription_created,
        "customer.subscription.updated" => :subscription_updated,
        "customer.subscription.deleted" => :subscription_cancelled
      }.freeze

      def create_customer(account)
        customer = post("/customers", customer_params(account))
        Result.new(external_id: customer["id"], raw: customer)
      end

      def update_customer(account)
        customer = post("/customers/#{account.external_customer_id}", customer_params(account))
        Result.new(external_id: customer["id"], raw: customer)
      end

      def create_plan(plan)
        product = post("/products", product_params(plan))
        price = post("/prices", price_params(plan, product["id"]))
        plan_result(product, price)
      end

      def update_plan(plan, reference)
        product = post("/products/#{reference.external_id}", product_params(plan))
        previous_price_id = reference.metadata["price_id"]
        price = current_price(plan, product["id"], previous_price_id)
        plan_result(product, price)
      end

      def archive_plan(_plan, reference)
        price_id = reference.metadata["price_id"]
        post("/prices/#{price_id}", active: false) if price_id
        product = post("/products/#{reference.external_id}", active: false)
        Result.new(external_id: product["id"], status: "archived",
                   raw: product.merge("price_id" => price_id, "archived" => true))
      end

      def create_subscription(_billing, account, plan_reference)
        price_id = plan_reference&.metadata&.dig("price_id")
        raise ConfigurationError, "stripe: plan has no price_id" if price_id.blank?

        subscription = post("/subscriptions", customer: account.external_customer_id,
                                              "items[0][price]" => price_id)
        subscription_result(subscription)
      end

      # Swaps the subscription item onto the billing's current plan price when it
      # changed; otherwise just refreshes the remote state.
      def update_subscription(billing, reference)
        subscription = get("/subscriptions/#{reference.external_id}")
        item = subscription.dig("items", "data", 0) || {}
        price_id = billing.plan&.provider_reference_for(provider_name)&.metadata&.dig("price_id")
        return subscription_result(subscription) if price_id.blank? || item.dig("price", "id") == price_id

        subscription_result(post("/subscriptions/#{reference.external_id}",
                                 "items[0][id]" => item["id"], "items[0][price]" => price_id))
      end

      def cancel_subscription(_billing, reference)
        subscription_result(delete("/subscriptions/#{reference.external_id}"))
      end

      def create_payment(charge, account)
        session = post("/checkout/sessions", checkout_params(charge, account))
        payment_result(session)
      end

      def fetch_payment(charge)
        payment_result(get("/checkout/sessions/#{charge.external_id}"))
      end

      def cancel_payment(charge)
        session = post("/checkout/sessions/#{charge.external_id}/expire", {})
        payment_result(session, status: "cancelled")
      end

      def verify_webhook!(payload, headers)
        timestamp, signatures = parse_signature_header(headers["Stripe-Signature"] || headers["HTTP_STRIPE_SIGNATURE"])
        raise InvalidWebhookSignature, "stripe: timestamp outside tolerance" if stale?(timestamp)

        expected = sign("#{timestamp}.#{payload}")
        return true if signatures.any? { |signature| secure_compare(signature, expected) }

        raise InvalidWebhookSignature, "stripe: signature mismatch"
      end

      def parse_webhook(payload, _headers)
        event = payload.is_a?(String) ? JSON.parse(payload) : payload.to_h.deep_stringify_keys
        object = event.dig("data", "object") || {}
        type = WEBHOOK_EVENTS.fetch(event["type"], :ignored)
        occurred_at = event["created"] && Time.zone.at(event["created"])
        WebhookEvent.new(type: type, external_id: object["id"], occurred_at: occurred_at, raw: event)
      end

      private

      # --- Params ------------------------------------------------------------

      def customer_params(account)
        entity = account.billable_entity
        {
          name: entity.try(:name),
          email: entity.try(:email),
          "metadata[active_billing_account_id]" => account.id,
          "metadata[billable_entity_type]" => account.billable_entity_type,
          "metadata[billable_entity_id]" => account.billable_entity_id
        }.compact
      end

      def product_params(plan)
        { name: plan.name, active: plan.active, "metadata[active_billing_plan_id]" => plan.id }
      end

      def price_params(plan, product_id)
        {
          product: product_id,
          unit_amount: plan.price_in_cents&.cents.to_i,
          currency: currency,
          "recurring[interval]" => INTERVALS.fetch(plan.interval.to_s, "month"),
          "metadata[active_billing_plan_id]" => plan.id
        }
      end

      def checkout_params(charge, account)
        invoice = charge.invoice
        {
          mode: "payment",
          customer: account&.external_customer_id,
          client_reference_id: charge.uuid,
          success_url: setting!(:success_url),
          cancel_url: setting!(:cancel_url),
          "line_items[0][quantity]" => 1,
          "line_items[0][price_data][currency]" => currency,
          "line_items[0][price_data][unit_amount]" => invoice&.amount_in_cents&.cents.to_i,
          "line_items[0][price_data][product_data][name]" => invoice&.description.presence || charge.create_description,
          "metadata[active_billing_charge_id]" => charge.id,
          "metadata[active_billing_invoice_id]" => invoice&.id
        }.compact
      end

      def currency
        ActiveBilling.configuration.currency.to_s.downcase
      end

      # --- Results -----------------------------------------------------------

      def current_price(plan, product_id, previous_price_id)
        previous = previous_price_id && get("/prices/#{previous_price_id}")
        return previous if previous && price_matches?(previous, plan)

        price = post("/prices", price_params(plan, product_id))
        post("/prices/#{previous_price_id}", active: false) if previous_price_id
        price
      end

      def price_matches?(price, plan)
        price["unit_amount"] == plan.price_in_cents&.cents.to_i &&
          price["currency"].to_s.downcase == currency &&
          price.dig("recurring", "interval") == INTERVALS.fetch(plan.interval.to_s, "month")
      end

      def plan_result(product, price)
        Result.new(external_id: product["id"], status: product["active"] ? "active" : "archived",
                   raw: product.merge("price_id" => price["id"], "price" => price))
      end

      def subscription_result(subscription)
        Result.new(external_id: subscription["id"], status: subscription["status"], raw: subscription)
      end

      def payment_result(session, status: nil)
        Result.new(external_id: session["id"], status: status || payment_status_for(session),
                   url: session["url"], raw: session)
      end

      def payment_status_for(session)
        SESSION_STATUSES[session["status"]] || PAYMENT_STATUSES.fetch(session["payment_status"], "pending")
      end

      # --- Webhook signature -------------------------------------------------

      def parse_signature_header(header)
        pairs = header.to_s.split(",").map { |pair| pair.strip.split("=", 2) }.group_by(&:first)
        timestamp = pairs.fetch("t", []).first&.last
        signatures = pairs.fetch("v1", []).map(&:last).compact
        if timestamp.nil? || signatures.empty?
          raise InvalidWebhookSignature, "stripe: missing or malformed Stripe-Signature header"
        end

        [timestamp, signatures]
      end

      def stale?(timestamp)
        tolerance = (setting(:webhook_tolerance) || WEBHOOK_TOLERANCE).to_i
        (Time.now.to_i - timestamp.to_i).abs > tolerance
      end

      def sign(signed_payload)
        OpenSSL::HMAC.hexdigest("SHA256", setting!(:webhook_secret), signed_payload)
      end

      def secure_compare(left, right)
        ActiveSupport::SecurityUtils.secure_compare(left.to_s, right.to_s)
      end

      # --- HTTP --------------------------------------------------------------

      def get(path)
        request(Net::HTTP::Get, path)
      end

      def post(path, params)
        request(Net::HTTP::Post, path, params)
      end

      def delete(path)
        request(Net::HTTP::Delete, path)
      end

      def request(klass, path, params = nil)
        uri = URI.parse("#{BASE_URL}#{path}")
        http_request = klass.new(uri)
        http_request["Authorization"] = "Bearer #{setting!(:api_key)}"
        http_request["Accept"] = "application/json"
        if params
          http_request["Content-Type"] = "application/x-www-form-urlencoded"
          http_request.body = URI.encode_www_form(params.compact)
        end
        handle(Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(http_request) })
      end

      def handle(response)
        body = parse_body(response.body)
        return body if response.is_a?(Net::HTTPSuccess)

        error = body["error"] || {}
        raise ApiError.new(error["message"] || "stripe: HTTP #{response.code}",
                           code: error["code"] || response.code, response: body)
      end

      def parse_body(body)
        return {} if body.blank?

        JSON.parse(body)
      rescue JSON::ParserError
        { "raw" => body }
      end
    end
  end
end
