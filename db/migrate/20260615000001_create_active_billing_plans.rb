class CreateActiveBillingPlans < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :active_billing_plans do |t|
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.string :name, null: false
      t.integer :price_in_cents, default: 0, null: false
      t.string :interval, default: 'monthly', null: false
      t.jsonb :allowances, default: {}, null: false
      t.boolean :active, default: true, null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps

      t.index :uuid, unique: true
      t.index :active
    end
  end
end
