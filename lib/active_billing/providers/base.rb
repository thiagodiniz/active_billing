# rubocop:disable Lint/UnusedMethodArgument
module ActiveBilling
  module Providers
    # Contract every payment-provider adapter must implement.
    #
    # An adapter is a thin, stateless wrapper around one provider's HTTP API. It is
    # instantiated with the settings hash configured for the provider and must not
    # write to the database: the `Synchronizer` and `WebhookProcessor` own all local
    # persistence and call the adapter only to talk to the remote service.
    #
    # Every method that touches a remote object returns a `Result`. Adapters raise
    # `ApiError` on remote failures, `NotSupported` for operations the provider has no
    # equivalent for, and `InvalidWebhookSignature` when a webhook cannot be trusted.
    #
    # Subclasses register themselves with `ActiveBilling::Providers.register(:name, self)`.
    class Base
      attr_reader :settings

      def self.provider_name
        name.demodulize.underscore.to_sym
      end

      def initialize(settings = {})
        @settings = (settings || {}).to_h.symbolize_keys
      end

      def provider_name
        self.class.provider_name
      end

      def setting(key)
        settings[key.to_sym]
      end

      def setting!(key)
        setting(key) || raise(ConfigurationError, "#{provider_name}: missing setting #{key}")
      end

      # --- Customers ---------------------------------------------------------
      # `account` is a ProviderAccount; `account.billable_entity` is the payer.

      def create_customer(account)
        not_supported!(__method__)
      end

      def update_customer(account)
        not_supported!(__method__)
      end

      # --- Catalog -----------------------------------------------------------
      # `reference` is the ProviderReference previously stored for the plan on
      # this provider.

      def create_plan(plan)
        not_supported!(__method__)
      end

      def update_plan(plan, reference)
        not_supported!(__method__)
      end

      def archive_plan(plan, reference)
        not_supported!(__method__)
      end

      # --- Subscriptions -----------------------------------------------------
      # `billing` is the local Billing; `account` its payer's ProviderAccount and
      # `plan_reference` the ProviderReference of the billing's plan on this provider.

      def create_subscription(billing, account, plan_reference)
        not_supported!(__method__)
      end

      def update_subscription(billing, reference)
        not_supported!(__method__)
      end

      def cancel_subscription(billing, reference)
        not_supported!(__method__)
      end

      # --- Payments ----------------------------------------------------------
      # `charge` is the local Charge; its `invoice` describes what is being paid
      # and `account` the payer's ProviderAccount.

      def create_payment(charge, account)
        not_supported!(__method__)
      end

      def fetch_payment(charge)
        not_supported!(__method__)
      end

      def cancel_payment(charge)
        not_supported!(__method__)
      end

      # --- Webhooks ----------------------------------------------------------
      # `payload` is the raw request body; `headers` a Hash of request headers.

      def verify_webhook!(payload, headers)
        not_supported!(__method__)
      end

      def parse_webhook(payload, headers)
        not_supported!(__method__)
      end

      private

      def not_supported!(operation)
        raise NotSupported.new(provider_name, operation)
      end
    end
  end
end
# rubocop:enable Lint/UnusedMethodArgument
