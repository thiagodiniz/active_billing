module ActiveBilling
  module Providers
    # Verifies, parses and applies an incoming provider webhook.
    #
    #   Providers::WebhookProcessor.new(:stripe).call(request.raw_post, request.headers.to_h)
    #
    # Payment events update the matching Charge; subscription events update the
    # matching Billing's ProviderReference metadata. Unknown objects are ignored so
    # providers can be pointed at the endpoint before any local record exists.
    class WebhookProcessor
      attr_reader :provider_name, :adapter

      def initialize(provider_name)
        @provider_name = provider_name.to_sym
        @adapter = Providers.build(@provider_name)
      end

      def call(payload, headers = {})
        adapter.verify_webhook!(payload, headers)
        event = adapter.parse_webhook(payload, headers)
        apply(event)
        event
      end

      def apply(event)
        return if event.ignored?

        if event.payment?
          apply_payment(event)
        elsif event.subscription?
          apply_subscription(event)
        end
      end

      private

      def apply_payment(event)
        charge = Charge.lookup(provider_name, event.external_id)
        charge&.apply_webhook_event!(event)
      end

      def apply_subscription(event)
        reference = ProviderReference.lookup(provider_name, event.external_id)
        return if reference.nil?

        reference.update!(metadata: reference.metadata.merge("status" => event.type.to_s.delete_prefix("subscription_"),
                                                             "last_webhook" => event.raw.deep_stringify_keys))
      end
    end
  end
end
