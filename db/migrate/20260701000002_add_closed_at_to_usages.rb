class AddClosedAtToUsages < ActiveRecord::Migration[7.0]
  def change
    add_column :active_billing_usages, :closed_at, :datetime
    add_index :active_billing_usages, :closed_at
  end
end
