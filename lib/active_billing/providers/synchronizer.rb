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

        account.store_provider_result!(account.provider, account.adapter.create_customer(account))
        account
      end

      def update_customer
        return create_customer unless record.synced?

        record.store_provider_result!(record.provider, record.adapter.update_customer(record))
        record
      end

      # --- Catalog -----------------------------------------------------------
      # Plans are mirrored to every configured provider, since accounts on any of
      # them may subscribe to the plan.

      def create_plan
        Providers.configured_names.map { |name| sync_plan_on(name) }
      end

      def update_plan
        record.active? ? create_plan : archive_plan
      end

      def archive_plan
        record.provider_ids.keys.filter_map do |name|
          reference = record.provider_reference_for(name)
          Providers.build(name).archive_plan(record, reference) if reference
          reference
        end
      end

      # --- Subscriptions -----------------------------------------------------

      def create_subscription
        return if record.plan.nil?

        account = ensure_account!(record.billable_entity)
        return if account.nil?
        return update_subscription if record.provider_reference_for(account.provider)

        create_subscription_on(account)
      end

      def create_subscription_on(account)
        plan_reference = sync_plan_on(account.provider, plan: record.plan)
        result = account.adapter.create_subscription(record, account, plan_reference)
        record.store_provider_result!(account.provider, result)
      end

      def sync_subscription
        record.finalized? ? cancel_subscription : update_subscription
      end

      def update_subscription
        account, reference = subscription_reference
        return create_subscription if reference.nil?

        record.store_provider_result!(account.provider, account.adapter.update_subscription(record, reference))
      end

      def cancel_subscription
        account, reference = subscription_reference
        return if reference.nil?

        record.store_provider_result!(account.provider, account.adapter.cancel_subscription(record, reference))
      end

      # --- Payments ----------------------------------------------------------

      def create_payment
        return record if record.synced?

        account = ensure_account!(record.payer_entity)
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

      def ensure_account!(entity)
        account = ProviderAccount.ensure_for!(entity)
        return if account.nil?
        return account if account.synced?

        Synchronizer.new(account).create_customer
      end

      def sync_plan_on(provider, plan: record)
        adapter = Providers.build(provider)
        reference = plan.provider_reference_for(provider)
        result = reference ? adapter.update_plan(plan, reference) : adapter.create_plan(plan)
        # A plan lives on every provider; the first one it reaches becomes "current".
        plan.store_provider_result!(provider, result, current: plan.provider.blank? || plan.provider == provider.to_s)
        plan.provider_reference_for(provider)
      end
    end
  end
end
