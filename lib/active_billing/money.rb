require "bigdecimal"

module ActiveBilling
  # Immutable money value object stored internally as integer cents.
  # Used by ActiveBilling::Type::Money to back the `*_in_cents` columns.
  class Money
    include Comparable

    attr_reader :cents, :currency

    def self.from_cents(cents, currency = ActiveBilling.configuration.currency)
      new(cents, currency)
    end

    def self.from_amount(amount, currency = ActiveBilling.configuration.currency)
      new((BigDecimal(amount.to_s) * 100).round, currency)
    end

    def self.to_cents(value)
      case value
      when Money then value.cents
      when Integer then value
      when Numeric, String then value.to_i
      else 0
      end
    end

    def initialize(cents, currency = ActiveBilling.configuration.currency)
      @cents = cents.to_i
      @currency = currency
    end

    # Decimal amount in major units (exact, never a lossy Float).
    def amount
      BigDecimal(cents) / 100
    end
    alias to_d amount

    def to_f
      amount.to_f
    end

    def to_i
      cents
    end

    def zero?
      cents.zero?
    end

    def +(other)
      self.class.new(cents + self.class.to_cents(other), currency)
    end

    def -(other)
      self.class.new(cents - self.class.to_cents(other), currency)
    end

    def <=>(other)
      cents <=> self.class.to_cents(other)
    end

    # Serializes to the integer cents value, keeping JSON stable and exact.
    def as_json(*)
      cents
    end

    def to_s
      format("%<currency>s %<amount>.2f", currency: currency, amount: amount)
    end

    def inspect
      "#<ActiveBilling::Money #{self}>"
    end
  end
end
