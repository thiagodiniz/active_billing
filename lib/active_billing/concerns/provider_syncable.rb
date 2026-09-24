module ActiveBilling
  module Concerns
    # Mirrors a record to the payment provider(s) after it is committed.
    #
    #   sync_with_provider create: :create_plan, update: :update_plan, if: :saved_changes?
    #
    # Each option names a `Providers::Synchronizer` operation. Syncing runs through
    # `ProviderSyncJob` when `provider_sync_async` is on, inline otherwise, and is
    # skipped entirely when `provider_sync_enabled` is off.
    module ProviderSyncable
      extend ActiveSupport::Concern

      included do
        attr_accessor :skip_provider_sync

        has_many :provider_references, as: :record,
                                       class_name: "ActiveBilling::ProviderReference",
                                       dependent: :destroy
      end

      class_methods do
        def sync_with_provider(create: nil, update: nil, destroy: nil, if: nil)
          condition = binding.local_variable_get(:if)

          after_commit(on: :create) { enqueue_provider_sync(create) } if create
          after_commit(on: :destroy) { enqueue_provider_sync(destroy) } if destroy
          return unless update

          after_commit(on: :update) do
            enqueue_provider_sync(update) if condition.nil? || provider_sync_condition_met?(condition)
          end
        end
      end

      def provider_reference_for(provider)
        provider_references.find { |reference| reference.provider == provider.to_s }
      end

      def synced_with?(provider)
        provider_reference_for(provider).present?
      end

      def without_provider_sync
        previous = skip_provider_sync
        self.skip_provider_sync = true
        yield self
      ensure
        self.skip_provider_sync = previous
      end

      def enqueue_provider_sync(operation)
        return if operation.nil?
        return if skip_provider_sync
        return unless ActiveBilling.configuration.provider_sync_enabled
        return if Providers.configured_names.empty?

        if ActiveBilling.configuration.provider_sync_async
          ProviderSyncJob.perform_later(self, operation.to_s)
        else
          Providers::Synchronizer.perform(self, operation)
        end
      end

      private

      def provider_sync_condition_met?(condition)
        condition.is_a?(Proc) ? instance_exec(&condition) : send(condition)
      end
    end
  end
end
