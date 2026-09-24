require "json"
require "securerandom"

module ActiveBilling
  module Providers
    # In-memory adapter used by the engine's own specs and as a reference for
    # implementing real providers. Every call is recorded in `Test.calls`; remote
    # objects live in `Test.store` and reset with `Test.reset!`.
    #
    # Webhooks are plain JSON bodies `{ "type": "payment_paid", "id": "..." }`
    # and are trusted when the `X-Test-Signature` header equals the configured
    # `webhook_secret` (or when no secret is configured).
    class Test < Base
      class << self
        def calls
          @calls ||= []
        end

        def store
          @store ||= Hash.new { |hash, key| hash[key] = {} }
        end

        def reset!
          @calls = []
          @store = nil
        end
      end

      def create_customer(account)
        remember(:customers, __method__, account, name: account.billable_entity.try(:name))
      end

      def update_customer(account)
        remember(:customers, __method__, account, name: account.billable_entity.try(:name),
                                                  external_id: account.external_customer_id)
      end

      def create_plan(plan)
        remember(:plans, __method__, plan, plan.to_snapshot)
      end

      def update_plan(plan, reference)
        remember(:plans, __method__, plan, plan.to_snapshot.merge(external_id: reference.external_id))
      end

      def archive_plan(plan, reference)
        remember(:plans, __method__, plan, { external_id: reference.external_id, status: "archived" })
      end

      def create_subscription(billing, account, plan_reference)
        remember(:subscriptions, __method__, billing,
                 customer_id: account.external_customer_id, plan_id: plan_reference&.external_id, status: "active")
      end

      def update_subscription(billing, reference)
        remember(:subscriptions, __method__, billing, external_id: reference.external_id, status: "active")
      end

      def cancel_subscription(billing, reference)
        remember(:subscriptions, __method__, billing, external_id: reference.external_id, status: "cancelled")
      end

      def create_payment(charge, account)
        remember(:payments, __method__, charge,
                 customer_id: account&.external_customer_id,
                 amount_in_cents: charge.invoice&.amount_in_cents&.cents,
                 status: "pending",
                 url: "https://pay.test/#{charge.uuid}")
      end

      def fetch_payment(charge)
        record = self.class.store[:payments][charge.external_id] || {}
        calls << [__method__, charge]
        Result.new(external_id: charge.external_id, status: record[:status] || "pending", url: record[:url],
                   raw: record)
      end

      def cancel_payment(charge)
        remember(:payments, __method__, charge, external_id: charge.external_id, status: "cancelled")
      end

      def verify_webhook!(_payload, headers)
        secret = setting(:webhook_secret)
        return true if secret.nil? || headers["X-Test-Signature"] == secret

        raise InvalidWebhookSignature, "test: signature mismatch"
      end

      def parse_webhook(payload, _headers)
        data = payload.is_a?(String) ? JSON.parse(payload) : payload.to_h.stringify_keys
        WebhookEvent.new(type: data["type"] || "ignored", external_id: data["id"],
                         occurred_at: data["occurred_at"], raw: data)
      end

      private

      def calls
        self.class.calls
      end

      def remember(collection, operation, record, attributes)
        external_id = attributes[:external_id] || "#{collection.to_s.singularize}_#{SecureRandom.hex(6)}"
        entry = attributes.merge(external_id: external_id, local_id: record.id)
        self.class.store[collection][external_id] = entry
        calls << [operation, record]
        Result.new(external_id: external_id, status: entry[:status], url: entry[:url], raw: entry)
      end
    end
  end
end
