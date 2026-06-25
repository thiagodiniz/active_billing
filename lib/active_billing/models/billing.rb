module ActiveBilling
  class Billing < ActiveRecord::Base
    enum :state, {
      open: "open",
      finalized: "finalized"
    }, default: "open"

    belongs_to :billable_entity, polymorphic: true
    belongs_to :plan, class_name: "ActiveBilling::Plan", optional: true

    has_many :usages, class_name: "ActiveBilling::Usage", dependent: :nullify
    has_many :invoices, class_name: "ActiveBilling::Invoice", dependent: :nullify

    validates :state, presence: true

    before_validation :snapshot_plan

    scope :for_billable_entity, ->(type, id) { where(billable_entity_type: type, billable_entity_id: id) }

    def self.current_for(entity)
      return if entity.nil?

      for_billable_entity(entity.class.name, entity.id).open.order(:created_at).last
    end

    private

    def snapshot_plan
      return unless open?
      return if plan.nil?

      self.plan_name = plan.name
      self.plan_price_in_cents = plan.price_in_cents&.cents
      self.plan_allowances = plan.allowances
    end
  end
end
