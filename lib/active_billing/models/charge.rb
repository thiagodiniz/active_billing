module ActiveBilling
  class Charge < ActiveRecord::Base
    include Concerns::ProviderSyncable

    FINISHED_STATES = %w[paid failed expired cancelled].freeze

    attribute :default_penalty, default: -> { ActiveBilling.configuration.default_penalty }
    attribute :default_interest, default: -> { ActiveBilling.configuration.default_interest }

    belongs_to :resource, polymorphic: true
    belongs_to :invoice, class_name: "ActiveBilling::Invoice", optional: true

    has_many :usages, through: :invoice

    enum :state, {
      created: "created",
      pending: "pending",
      processing: "processing",
      paid: "paid",
      failed: "failed",
      expired: "expired",
      cancelled: "cancelled"
    }, default: "created"

    validates :state, presence: true
    validates :external_id, uniqueness: { scope: :provider }, allow_nil: true

    scope :for_billable_entity, ->(type, id) {
      joins(invoice: :billing).where(active_billing_billings: { billable_entity_type: type, billable_entity_id: id })
    }
    scope :for_provider, ->(name) { where(provider: name.to_s) }
    scope :unfinished, -> { where.not(state: FINISHED_STATES) }

    sync_with_provider create: :create_payment

    alias payer resource

    def self.lookup(provider, external_id)
      for_provider(provider).find_by(external_id: external_id.to_s)
    end

    def billing_entity
      # Override this method in your application to return the entity that receives payments
      # For example: Company.billing_company or Organization.billing_organization
      raise NotImplementedError, "Implement billing_entity method in your Charge class"
    end
    alias recipient billing_entity

    def billing_entity_id
      billing_entity&.id
    end

    def payer_legal_name
      payer.respond_to?(:billing_legal_name) ? payer.billing_legal_name : payer.name
    end

    def payer_tax_document
      payer.respond_to?(:billing_tax_document) ? payer.billing_tax_document : nil
    end

    def create_description
      I18n.t("active_billing.charge.billing_description",
             default: "Monthly subscription and usage charges")
    end

    def payable_due_at
      invoice&.issued_at || invoice&.created_at
    end

    def finished?
      FINISHED_STATES.include?(state)
    end

    def synced?
      external_id.present?
    end

    def provider_account
      invoice&.provider_account || ProviderAccount.current_for(resource)
    end

    # Applies a `Providers::Result` returned by the adapter for this charge.
    def apply_provider_result!(provider_name, result)
      without_provider_sync do
        update!(provider: provider_name.to_s,
                external_id: result.external_id,
                payment_url: result.url || payment_url,
                metadata: metadata.merge(result.raw.deep_stringify_keys),
                **state_attributes_for(result.status))
      end
    end

    # Applies a `Providers::WebhookEvent` about this charge.
    def apply_webhook_event!(event)
      return unless event.payment?
      return if finished?

      without_provider_sync do
        update!(metadata: metadata.merge("last_webhook" => event.raw.deep_stringify_keys),
                **state_attributes_for(event.payment_status, at: event.occurred_at))
      end
    end

    def refresh_from_provider!
      return unless synced?

      Providers::Synchronizer.perform(self, :fetch_payment)
    end

    private

    def state_attributes_for(status, at: nil)
      return {} if status.blank? || !self.class.states.key?(status.to_s)

      attributes = { state: status.to_s }
      timestamp_column = "#{status}_at"
      attributes[timestamp_column] = at || Time.current if has_attribute?(timestamp_column)
      attributes
    end
  end
end
