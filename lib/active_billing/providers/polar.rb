require "json"
require "active_billing/providers/polar/client"
require "active_billing/providers/polar/mapping"
require "active_billing/providers/polar/webhooks"

module ActiveBilling
  module Providers
    # Adapter for Polar.sh (https://docs.polar.sh/api-reference).
    #
    # Settings:
    #   api_key            - organization access token (required)
    #   webhook_secret     - endpoint secret, `whsec_...` (required to receive webhooks)
    #   sandbox            - true to talk to https://sandbox-api.polar.sh
    #   success_url        - where Polar redirects the payer after a checkout
    #   payment_product_id - optional one-time product reused for every Charge checkout
    #
    # Polar has no server-side "create subscription" for paid products: a customer
    # subscribes by completing a Checkout Session. `create_subscription` therefore
    # returns the checkout (id, hosted url, status "pending") and the resulting
    # `subscription_id` is learned from `subscription.*` webhooks, whose payloads
    # carry `checkout_id`. Charges follow the same model with a one-time checkout.
    class Polar < Base
      include Mapping
      include Webhooks

      PRODUCTION_URL = "https://api.polar.sh/v1".freeze
      SANDBOX_URL = "https://sandbox-api.polar.sh/v1".freeze

      INTERVALS = { "monthly" => "month", "yearly" => "year" }.freeze

      CHECKOUT_STATUSES = {
        "open" => "pending",
        "confirmed" => "processing",
        "succeeded" => "paid",
        "failed" => "failed",
        "expired" => "expired"
      }.freeze

      SUBSCRIPTION_EVENTS = {
        "subscription.created" => :subscription_created,
        "subscription.updated" => :subscription_updated,
        "subscription.active" => :subscription_updated,
        "subscription.uncanceled" => :subscription_updated,
        "subscription.cycled" => :subscription_updated,
        "subscription.past_due" => :subscription_updated,
        "subscription.paused" => :subscription_updated,
        "subscription.resumed" => :subscription_updated,
        "subscription.migrated" => :subscription_updated,
        "subscription.canceled" => :subscription_cancelled,
        "subscription.revoked" => :subscription_cancelled
      }.freeze

      SIGNATURE_TOLERANCE = 5 * 60

      # --- Customers ---------------------------------------------------------

      def create_customer(account)
        customer = client.post("/customers", customer_attributes(account))
        Result.new(external_id: customer["id"], raw: customer_raw(customer))
      end

      def update_customer(account)
        customer = client.patch("/customers/#{account.external_customer_id}", customer_attributes(account))
        Result.new(external_id: customer["id"], raw: customer_raw(customer))
      end

      # --- Catalog -----------------------------------------------------------

      def create_plan(plan)
        product = client.post("/products", product_attributes(plan).merge(recurring_interval: interval_for(plan)))
        product_result(product)
      end

      # `recurring_interval` is immutable on Polar products, so an interval change
      # is not propagated.
      def update_plan(plan, reference)
        product = client.patch("/products/#{reference.external_id}",
                               product_attributes(plan).merge(is_archived: !plan.active))
        product_result(product)
      end

      def archive_plan(_plan, reference)
        product = client.patch("/products/#{reference.external_id}", is_archived: true)
        product_result(product, status: "archived")
      end

      # --- Subscriptions -----------------------------------------------------

      def create_subscription(billing, account, plan_reference)
        checkout = client.post("/checkouts", checkout_attributes(account).merge(
                                               products: [plan_reference.external_id],
                                               metadata: { "active_billing_billing_id" => billing.id.to_s }
                                             ))
        checkout_result(checkout, status: "pending")
      end

      def update_subscription(billing, reference)
        subscription_id = subscription_id_for(reference)
        return checkout_result(fetch_checkout(reference.external_id), status: "pending") if subscription_id.nil?

        body = { metadata: { "active_billing_billing_id" => billing.id.to_s } }
        product_id = billing.plan&.provider_reference_for(provider_name)&.external_id
        body[:product_id] = product_id if product_id
        subscription_result(client.patch("/subscriptions/#{subscription_id}", body), reference)
      end

      # Cancels at period end by default; `settings[:revoke] = true` revokes access
      # immediately instead. A checkout that never turned into a subscription has
      # nothing to cancel remotely and is reported as cancelled.
      def cancel_subscription(_billing, reference)
        subscription_id = subscription_id_for(reference)
        return checkout_result(fetch_checkout(reference.external_id), status: "cancelled") if subscription_id.nil?

        body = setting(:revoke) ? { revoke: true } : { cancel_at_period_end: true }
        subscription_result(client.patch("/subscriptions/#{subscription_id}", body), reference, status: "cancelled")
      end

      # --- Payments ----------------------------------------------------------

      def create_payment(charge, account)
        product_id = setting(:payment_product_id) || create_payment_product(charge)["id"]
        checkout = client.post("/checkouts", payment_checkout_attributes(charge, account, product_id))
        checkout_result(checkout).tap { |result| result.raw["product_id"] = product_id }
      end

      def fetch_payment(charge)
        checkout_result(fetch_checkout(charge.external_id))
      end

      # Polar checkouts cannot be cancelled through the API; they expire on their own.
      def cancel_payment(_charge)
        not_supported!(__method__)
      end

      # --- Webhooks ----------------------------------------------------------
      # Standard Webhooks: `webhook-signature` is `v1,<base64 hmac>` over
      # "#{id}.#{timestamp}.#{body}". Secrets issued before 2026-09-08 are keyed by the
      # raw `whsec_...` string, newer ones by its base64-decoded payload; both are tried.

      def verify_webhook!(payload, headers)
        id, timestamp, signature = webhook_headers(headers)
        raise InvalidWebhookSignature, "polar: webhook timestamp outside tolerance" unless fresh?(timestamp)

        expected = signing_keys.map { |key| sign(key, "#{id}.#{timestamp}.#{payload}") }
        return true if signatures_in(signature).any? { |sig| expected.any? { |exp| secure_compare(sig, exp) } }

        raise InvalidWebhookSignature, "polar: signature mismatch"
      end

      def parse_webhook(payload, _headers)
        event = payload.is_a?(String) ? JSON.parse(payload) : payload.to_h.deep_stringify_keys
        data = event["data"] || {}
        WebhookEvent.new(type: webhook_type_for(event["type"], data),
                         external_id: webhook_external_id(event["type"], data),
                         occurred_at: parse_time(event["timestamp"]), raw: event)
      end

      private

      def client
        @client ||= Client.new(setting!(:api_key), setting(:sandbox) ? SANDBOX_URL : PRODUCTION_URL)
      end
    end
  end
end
