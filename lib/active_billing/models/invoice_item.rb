module ActiveBilling
  class InvoiceItem < ActiveRecord::Base
    self.table_name = 'active_billing_invoice_items'

    belongs_to :invoice, class_name: 'ActiveBilling::Invoice',
               foreign_key: 'billing_invoice_id',
               inverse_of: :items
    belongs_to :usage, class_name: 'ActiveBilling::Usage',
               inverse_of: :invoice_items,
               optional: true

    validates :quantity, numericality: { greater_than: 0, only_integer: true }
    validates :key, presence: true, allow_blank: false
    validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

    before_validation :set_price

    def estimated_price
      quantity.to_i * unit_price.to_d
    end

    def price
      return self[:price] if self[:price].present?

      self[:price] = estimated_price
      self[:price]
    end

    private

    def set_price
      self.price = estimated_price
    end
  end
end
