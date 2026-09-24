require "active_billing/providers/abacatepay/client"
require "active_billing/providers/abacatepay/webhooks"
require "active_billing/providers/abacatepay/attributes"

module ActiveBilling
  module Providers
    # AbacatePay adapter (https://docs.abacatepay.com, API v2). BRL only.
    #
    # Mapping onto the AbacatePay API:
    #   * customers      -> POST /customers/create (no update endpoint)
    #   * plans          -> products with a recurring `cycle` (POST /products/create,
    #                       POST /products/delete; products are immutable)
    #   * subscriptions  -> POST /subscriptions/create returns a hosted checkout; the
    #                       `subs_` id only exists after the customer pays and is
    #                       learned from the `subscription.*` webhooks
    #   * payments       -> transparent PIX charge (POST /transparents/create,
    #                       GET /transparents/check). Hosted checkouts require
    #                       pre-registered products, so they do not fit ad-hoc invoices.
    class Abacatepay < Base
      PAYMENT_STATUSES = {
        "PENDING" => "pending",
        "UNDER_DISPUTE" => "processing",
        "PAID" => "paid",
        "APPROVED" => "paid",
        "REDEEMED" => "paid",
        "FAILED" => "failed",
        "EXPIRED" => "expired",
        "CANCELLED" => "cancelled",
        "REFUNDED" => "cancelled"
      }.freeze

      include Attributes
      include Webhooks

      # --- Customers ----------------------------------------------------------

      def create_customer(account)
        data = client.post("/customers/create", customer_attributes(account))
        Result.new(external_id: data["id"], raw: data)
      end

      # AbacatePay exposes no endpoint to update a customer.
      def update_customer(_account)
        not_supported!(__method__)
      end

      # --- Plans --------------------------------------------------------------

      def create_plan(plan)
        data = client.post("/products/create", product_attributes(plan))
        Result.new(external_id: data["id"], raw: data)
      end

      # Products are immutable; create a new plan instead.
      def update_plan(_plan, _reference)
        not_supported!(__method__)
      end

      def archive_plan(_plan, reference)
        data = client.post("/products/delete", id: reference.external_id)
        Result.new(external_id: reference.external_id, status: "archived", raw: data)
      end

      # --- Subscriptions ------------------------------------------------------

      def create_subscription(billing, account, plan_reference)
        data = client.post("/subscriptions/create", subscription_attributes(billing, account, plan_reference))
        Result.new(external_id: data["id"], status: "pending", url: data["url"], raw: data)
      end

      def update_subscription(billing, reference)
        plan_reference = billing.plan&.provider_reference_for(provider_name)
        raise Error, "#{provider_name}: billing has no synced plan to change to" if plan_reference.nil?

        data = client.post("/subscriptions/change-plan",
                           subscriptionId: subscription_id_for(reference), productId: plan_reference.external_id)
        Result.new(external_id: reference.external_id, status: "active", raw: data)
      end

      def cancel_subscription(_billing, reference)
        data = client.post("/subscriptions/cancel", subscriptionId: subscription_id_for(reference), cancelPolicy: "NOW")
        Result.new(external_id: reference.external_id, status: "cancelled", raw: data)
      end

      # --- Payments -----------------------------------------------------------

      def create_payment(charge, account)
        ensure_brl!

        data = client.post("/transparents/create", method: "PIX", data: payment_attributes(charge, account))
        Result.new(external_id: data["id"], status: payment_status(data["status"]), raw: data)
      end

      def fetch_payment(charge)
        data = client.get("/transparents/check", id: charge.external_id)
        Result.new(external_id: charge.external_id, status: payment_status(data["status"]), raw: data)
      end

      # AbacatePay has no cancel endpoint for PIX charges; they expire on their own.
      def cancel_payment(_charge)
        not_supported!(__method__)
      end

      private

      def client
        Client.new(api_key: setting!(:api_key), base_url: setting(:base_url), provider_name: provider_name)
      end

      def payment_status(remote_status)
        PAYMENT_STATUSES[remote_status.to_s] ||
          raise(Error, "#{provider_name}: unknown payment status #{remote_status}")
      end

      # The `subs_` id is only known once the customer pays the checkout returned by
      # create_subscription; WebhookProcessor stores that webhook in the reference.
      def subscription_id_for(reference)
        id = reference.metadata["subscription_id"] ||
             reference.metadata.dig("last_webhook", "data", "subscription", "id")
        raise Error, "#{provider_name}: subscription #{reference.external_id} has not been activated yet" if id.nil?

        id
      end

      def ensure_brl!
        currency = ActiveBilling.configuration.currency.to_s.upcase
        return if currency == "BRL"

        raise ConfigurationError, "#{provider_name}: only BRL is supported (configured currency: #{currency})"
      end
    end
  end
end
