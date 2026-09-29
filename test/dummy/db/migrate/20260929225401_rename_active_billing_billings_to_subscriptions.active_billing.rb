# This migration comes from active_billing (originally 20260924000002)
class RenameActiveBillingBillingsToSubscriptions < ActiveRecord::Migration[7.0]
  def change
    rename_table :active_billing_billings, :active_billing_subscriptions
    rename_column :active_billing_usages, :billing_id, :subscription_id
    rename_column :active_billing_invoices, :billing_id, :subscription_id
  end
end
