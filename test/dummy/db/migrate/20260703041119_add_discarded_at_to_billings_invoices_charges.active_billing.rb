# This migration comes from active_billing (originally 20260701000001)
class AddDiscardedAtToBillingsInvoicesCharges < ActiveRecord::Migration[7.0]
  def change
    add_column :active_billing_billings, :discarded_at, :datetime
    add_index :active_billing_billings, :discarded_at

    add_column :active_billing_invoices, :discarded_at, :datetime
    add_index :active_billing_invoices, :discarded_at

    add_column :active_billing_charges, :discarded_at, :datetime
    add_index :active_billing_charges, :discarded_at
  end
end
