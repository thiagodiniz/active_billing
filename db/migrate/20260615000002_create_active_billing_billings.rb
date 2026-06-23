class CreateActiveBillingBillings < ActiveRecord::Migration[7.0]
  def change
    create_table :active_billing_billings do |t|
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.references :billable_entity, polymorphic: true, null: false
      t.references :plan, foreign_key: { to_table: :active_billing_plans }
      t.string :plan_name
      t.integer :plan_price_in_cents
      t.jsonb :plan_allowances, default: {}, null: false
      t.string :state, default: 'open', null: false
      t.date :period_start
      t.date :period_end
      t.jsonb :metadata, default: {}, null: false

      t.timestamps

      t.index :uuid, unique: true
      t.index :state
    end
  end
end
