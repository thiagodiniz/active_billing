module ActiveBilling
  module ApplicationHelper
    def format_cents(value)
      return "-" if value.nil?
      return value.to_s if value.is_a?(ActiveBilling::Money)

      ActiveBilling::Money.from_cents(value.to_i).to_s
    end
  end
end
