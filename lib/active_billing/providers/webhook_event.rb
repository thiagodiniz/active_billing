module ActiveBilling
  module Providers
    # Provider-agnostic representation of an incoming webhook, produced by
    # `Base#parse_webhook`. `type` must be one of TYPES; anything the adapter does
    # not care about should be mapped to `:ignored`.
    WEBHOOK_EVENT_TYPES = %i[
      payment_pending
      payment_processing
      payment_paid
      payment_failed
      payment_expired
      payment_cancelled
      subscription_created
      subscription_updated
      subscription_cancelled
      ignored
    ].freeze

    WebhookEvent = Struct.new(:type, :external_id, :occurred_at, :raw, keyword_init: true) do
      def initialize(type:, external_id: nil, occurred_at: nil, raw: {})
        type = type.to_sym
        raise ArgumentError, "unknown webhook event type: #{type}" unless WEBHOOK_EVENT_TYPES.include?(type)

        super(type: type, external_id: external_id&.to_s, occurred_at: occurred_at, raw: raw || {})
      end

      def payment?
        type.to_s.start_with?("payment_")
      end

      def subscription?
        type.to_s.start_with?("subscription_")
      end

      def ignored?
        type == :ignored
      end

      # Charge state implied by a payment event, e.g. :payment_paid => "paid".
      def payment_status
        type.to_s.delete_prefix("payment_") if payment?
      end
    end
  end
end
