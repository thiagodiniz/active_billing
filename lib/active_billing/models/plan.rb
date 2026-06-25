module ActiveBilling
  class Plan < ActiveRecord::Base
    INTERVALS = %w[monthly yearly].freeze

    attribute :price_in_cents, :active_billing_money

    enum :interval, {
      monthly: "monthly",
      yearly: "yearly"
    }, default: "monthly"

    has_many :billings, class_name: "ActiveBilling::Billing", dependent: :nullify

    validates :name, presence: true
    validates :price_in_cents, comparison: { greater_than_or_equal_to: 0 }

    scope :active, -> { where(active: true) }

    def to_snapshot
      {
        plan_name: name,
        plan_price_in_cents: price_in_cents&.cents,
        plan_allowances: allowances
      }
    end
  end
end
