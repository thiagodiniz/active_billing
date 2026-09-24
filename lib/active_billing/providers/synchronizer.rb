module ActiveBilling
  module Providers
    # Orchestrates one sync operation between a local record and its provider(s).
    # Adapters only speak HTTP; this class picks the adapter for the record's payer,
    # satisfies prerequisites (customer before subscription, plan before
    # subscription) and persists the returned identifiers locally.
    class Synchronizer
      OPERATIONS = %i[
        create_customer update_customer
        create_plan update_plan archive_plan
        create_subscription sync_subscription update_subscription cancel_subscription
        create_payment fetch_payment cancel_payment
      ].freeze

      def self.perform(record, operation)
        new(record).perform(operation)
      end

      attr_reader :record

      def initialize(record)
        @record = record
      end

      def perform(operation)
        operation = operation.to_sym
        raise ArgumentError, "unknown sync operation: #{operation}" unless OPERATIONS.include?(operation)

        public_send(operation)
      end

      # --- Customers ---------------------------------------------------------

      def create_customer
        account = record
        return account if account.synced?

        result = account.adapter.create_customer(account)
        account.without_provider_sync do
          account.update!(external_customer_id: result.external_id,
                          metadata: account.metadata.merge(result.raw.deep_stringify_keys))
        end
        account
      end

      def update_customer
        return create_customer unless record.synced?

        record.adapter.update_customer(record)
        record
      end

      # --- Catalog -----------------------------------------------------------
      # Plans are mirrored to every configured provider, since accounts on any of
      # them may subscribe to the plan.

      def create_plan
        Providers.configured_names.map { |name| sync_plan_on(name) }
      end
      alias update_plan create_plan

      def archive_plan
        record.provider_references.map do |reference|
          Providers.build(reference.provider).archive_plan(record, reference)
          reference
        end
      end

      # --- Subscriptions -----------------------------------------------------

      def create_subscription
        return if record.plan.nil?

        account = ensure_account!(record.provider_account)
        return if account.nil?

        plan_reference = sync_plan_on(account.provider, plan: record.plan)
        result = account.adapter.create_subscription(record, account, plan_reference)
        ProviderReference.upsert_from(record, account.provider, result)
      end

      def sync_subscription
        record.finalized? ? cancel_subscription : update_subscription
      end

      def update_subscription
        account, reference = subscription_reference
        return create_subscription if reference.nil?

        result = account.adapter.update_subscription(record, reference)
        ProviderReference.upsert_from(record, account.provider, result)
      end

      def cancel_subscription
        account, reference = subscription_reference
        return if reference.nil?

        result = account.adapter.cancel_subscription(record, reference)
        ProviderReference.upsert_from(record, account.provider, result)
      end

      # --- Payments ----------------------------------------------------------

      def create_payment
        return record if record.synced?

        account = ensure_account!(record.provider_account)
        return record if account.nil?

        record.apply_provider_result!(account.provider, account.adapter.create_payment(record, account))
        record
      end

      def fetch_payment
        refresh_payment(:fetch_payment)
      end

      def cancel_payment
        refresh_payment(:cancel_payment)
      end

      private

      def subscription_reference
        account = record.provider_account
        [account, account && record.provider_reference_for(account.provider)]
      end

      def refresh_payment(operation)
        return record unless record.synced?

        record.apply_provider_result!(record.provider, Providers.build(record.provider).public_send(operation, record))
        record
      end

      def ensure_account!(account)
        return if account.nil?
        return account if account.synced?

        Synchronizer.new(account).create_customer
      end

      def sync_plan_on(provider, plan: record)
        adapter = Providers.build(provider)
        reference = plan.provider_reference_for(provider)
        result = reference ? adapter.update_plan(plan, reference) : adapter.create_plan(plan)
        ProviderReference.upsert_from(plan, provider, result)
      end
    end
  end
end
