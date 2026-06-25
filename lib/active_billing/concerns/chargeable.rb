module ActiveBilling
  module Concerns
    module Chargeable
      extend ActiveSupport::Concern

      SCOPES = %w[created pending processing paid cancelling cancelled overdue expired
                  current not_current active inactive].freeze

      included do
        include Discard::Model

        has_one :charge, as: :chargeable, touch: true, class_name: "ActiveBilling::Charge"
        has_one :gateway_wallet, through: :charge

        delegate :gateway_metadata, :expired?, :created?, :charged?, :paid_at, :paid?, :pending?,
                 :gateway_used, :due_at, :effective_at, :amount, :expires_days_after_due,
                 :discount_rate, :expected_amount_with_discount_in_cents, :gateway_charge_eid,
                 :state, :document_url, :discount_expires_at, :cancelled?, :issued_at,
                 :nosso_numero, :customer_paid_at, :barcode_number, :gateway_name,
                 to: :charge, allow_nil: true

        scope :gateway_charge_eid_equals, ->(eid) { joins(:charge).where(charge: { gateway_charge_eid: eid }) }
        scope :with_charges, -> { joins("INNER JOIN #{ActiveBilling::Charge.table_name} ON #{table_name}.id = charges.chargeable_id") }
        scope :state_equals, ->(state) { with_charges.where(charges: { state: state }) }
        scope :due_at_gteq_datetime, ->(date) { with_charges.where(charges: { due_at: (date..) }) }
        scope :due_at_lteq_datetime, ->(date) { with_charges.where(charges: { due_at: (..date) }) }
        scope :paid_at_gteq_datetime, ->(date) { with_charges.where(charges: { paid_at: (date..) }) }
        scope :paid_at_lteq_datetime, ->(date) { with_charges.where(charges: { paid_at: (..date) }) }

        SCOPES.each { |s| class_eval { scope :"#{s}", -> { with_charges.merge(ActiveBilling::Charge.send(s)) } } }

        def self.ransackable_scopes(_auth_object = nil)
          %i[state_equals gateway_charge_eid_equals due_at_gteq_datetime due_at_lteq_datetime
             paid_at_gteq_datetime paid_at_lteq_datetime]
        end
      end
    end
  end
end
