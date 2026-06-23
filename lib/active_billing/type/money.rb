require "active_record/type"

module ActiveBilling
  module Type
    # Custom ActiveRecord attribute type that maps an integer cents column to
    # an ActiveBilling::Money value object. Registered as `:active_billing_money`.
    #
    #   attribute :amount_in_cents, :active_billing_money
    #
    # Input is always interpreted as cents (matching the `_in_cents` column
    # name); use ActiveBilling::Money.from_amount to assign from major units.
    class Money < ActiveRecord::Type::Integer
      def type
        :active_billing_money
      end

      def cast(value)
        return if value.nil?
        return value if value.is_a?(ActiveBilling::Money)

        ActiveBilling::Money.from_cents(super)
      end

      def deserialize(value)
        return if value.nil?

        ActiveBilling::Money.from_cents(super)
      end

      def serialize(value)
        return if value.nil?

        super(value.is_a?(ActiveBilling::Money) ? value.cents : value)
      end

      def changed_in_place?(raw_old_value, new_value)
        deserialize(raw_old_value) != new_value
      end
    end
  end
end
