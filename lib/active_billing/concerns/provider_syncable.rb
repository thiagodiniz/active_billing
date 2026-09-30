module ActiveBilling
  module Concerns
    # Mirrors a record to the payment provider(s) after it is committed and keeps
    # the provider-side identifiers on the record itself:
    #
    #   provider     - provider currently in charge of the record
    #   provider_id  - the record's id on that provider
    #   provider_ids - { "stripe" => { "id" => "prod_1", ... }, "polar" => { ... } }
    #                  ids and metadata on every provider the record has been on
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

        scope :for_provider, ->(name) { where(provider: name.to_s) }
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

        # Finds the record by its id on `provider`, whether that provider is the
        # current one or a previous one.
        def lookup(provider, external_id)
          for_provider(provider).find_by(provider_id: external_id.to_s) ||
            where("#{table_name}.provider_ids -> ? ->> 'id' = ?", provider.to_s, external_id.to_s).first
        end
      end

      def provider_reference
        provider && provider_reference_for(provider)
      end

      def provider_reference_for(name)
        data = provider_ids[name.to_s]
        return if data.blank? || data["id"].blank?

        Providers::Reference.new(provider: name.to_s, external_id: data["id"], metadata: data.except("id"))
      end

      def synced_with?(name)
        provider_reference_for(name).present?
      end

      def synced?
        provider_id.present?
      end

      # Persists a `Providers::Result` for `name`; `current: true` also makes that
      # provider the record's current one.
      def store_provider_result!(name, result, current: true, **attributes)
        entry = (provider_ids[name.to_s] || {}).merge(result.raw.deep_stringify_keys, "id" => result.external_id)
        attributes[:provider_ids] = provider_ids.merge(name.to_s => entry)
        attributes.merge!(provider: name.to_s, provider_id: result.external_id) if current

        without_provider_sync { update!(attributes) }
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
