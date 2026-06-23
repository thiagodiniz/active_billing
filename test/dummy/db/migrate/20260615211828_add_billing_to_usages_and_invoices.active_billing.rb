# This migration comes from active_billing (originally 20260615000003)
class AddBillingToUsagesAndInvoices < ActiveRecord::Migration[7.0]
  def change
    add_reference :active_billing_usages, :billing,
                  foreign_key: { to_table: :active_billing_billings }
    add_reference :active_billing_invoices, :billing,
                  foreign_key: { to_table: :active_billing_billings }
  end
end
