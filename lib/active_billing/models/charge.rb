module ActiveBilling
  class Charge < ActiveRecord::Base
    include Chargeable

    self.table_name = 'active_billing_charges'

    attribute :default_penalty, default: -> { ActiveBilling.configuration.default_penalty }
    attribute :default_interest, default: -> { ActiveBilling.configuration.default_interest }

    belongs_to :resource, polymorphic: true
    belongs_to :invoice, class_name: 'ActiveBilling::Invoice', optional: true

    has_many :usages, through: :invoice

    scope :charged, -> { joins(:charge).where.not(charges: { state: 'created' }) }
    scope :active, -> { joins(:charge).where.not(charges: { state: %w[expired cancelled cancelling] }) }

    alias payer resource
    alias recipient billing_entity

    def billing_entity
      # Override this method in your application to return the entity that receives payments
      # For example: Company.billing_company or Organization.billing_organization
      raise NotImplementedError, "Implement billing_entity method in your Charge class"
    end

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
      I18n.t('active_billing.charge.billing_description',
             default: 'Monthly subscription and usage charges')
    end

    def charged_at
      charge&.charge_events&.where(kind: 'pending')&.order(:occurred_at)&.first&.occurred_at
    end

    def payable_due_at
      invoice&.issued_at || invoice&.created_at
    end
  end
end
