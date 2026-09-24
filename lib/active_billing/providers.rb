require "active_billing/providers/errors"
require "active_billing/providers/result"
require "active_billing/providers/webhook_event"
require "active_billing/providers/base"
require "active_billing/providers/test"
require "active_billing/providers/polar"

module ActiveBilling
  # Entry point for payment-provider adapters.
  #
  # Adapters are registered by name and instantiated on demand with the settings
  # found under `ActiveBilling.configuration.providers[name]`. Each billable entity
  # may live on a different provider (see `ProviderAccount`), so callers resolve the
  # adapter through `Providers.for(entity)` instead of hard-coding one.
  module Providers
    class << self
      def registry
        @registry ||= {}
      end

      def register(name, adapter_class)
        registry[name.to_sym] = adapter_class
      end

      def unregister(name)
        registry.delete(name.to_sym)
      end

      def registered?(name)
        registry.key?(name.to_sym)
      end

      def names
        registry.keys
      end

      def configured_names
        ActiveBilling.configuration.providers.keys.map(&:to_sym).select { |name| registered?(name) }
      end

      def fetch(name)
        registry.fetch(name.to_sym) { raise UnknownProvider, name }
      end

      # Builds an adapter for `name` using the settings configured for it.
      def build(name)
        settings = ActiveBilling.configuration.providers.fetch(name.to_sym) do
          ActiveBilling.configuration.providers.fetch(name.to_s, {})
        end
        fetch(name).new(settings)
      end

      # Resolves the provider name for a billable entity, in order of precedence:
      # its active `ProviderAccount`, the configured `provider_resolver`, then
      # `default_provider`.
      def name_for(billable_entity)
        account = ProviderAccount.current_for(billable_entity)
        return account.provider.to_sym if account

        resolved = ActiveBilling.configuration.provider_resolver&.call(billable_entity)
        (resolved || ActiveBilling.configuration.default_provider)&.to_sym
      end

      def for(billable_entity)
        name = name_for(billable_entity)
        if name.nil?
          raise UnknownProvider,
                "no provider configured for #{billable_entity.class.name}##{billable_entity.id}"
        end

        build(name)
      end
    end

    register :test, Test
    register :polar, Polar
  end
end
