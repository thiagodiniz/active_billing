module ActiveBilling
  class Charge < ActiveRecord::Base
    attribute :default_penalty, default: -> { ActiveBilling.configuration.default_penalty }
    attribute :default_interest, default: -> { ActiveBilling.configuration.default_interest }

    belongs_to :resource, polymorphic: true
    belongs_to :invoice, class_name: "ActiveBilling::Invoice", optional: true

    has_many :usages, through: :invoice

    scope :for_billable_entity, ->(type, id) {
      joins(invoice: :billing).where(active_billing_billings: { billable_entity_type: type, billable_entity_id: id })
    }

    alias payer resource

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
  end
end
