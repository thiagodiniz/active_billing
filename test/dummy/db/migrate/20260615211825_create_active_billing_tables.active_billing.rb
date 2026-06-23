# This migration comes from active_billing (originally 20260101000001)
class CreateActiveBillingTables < ActiveRecord::Migration[7.0]
  def change
    # Enable UUID extension if not already enabled
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    # Enable hstore for email timestamp storage
    enable_extension 'hstore' unless extension_enabled?('hstore')

    create_table :active_billing_charges do |t|
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.references :resource, polymorphic: true, null: false
      t.references :invoice
      t.integer :default_penalty
      t.integer :default_interest

      t.timestamps

      t.index :uuid, unique: true
    end

    create_table :active_billing_usages do |t|
      t.references :billable_entity, polymorphic: true, null: false
      t.date :month, null: false
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.integer :total_cost_in_cents, default: 0
      t.hstore :email_timestamps
      t.jsonb :metadata, default: {}, null: false

      t.timestamps

      t.index [:billable_entity_type, :billable_entity_id, :month],
              name: 'index_active_billing_usages_on_entity_and_month',
              unique: true
      t.index :month
      t.index :uuid, unique: true
    end

    create_table :active_billing_events do |t|
      t.references :billing_usage, null: false, foreign_key: { to_table: :active_billing_usages }
      t.references :resource, polymorphic: true
      t.string :kind, null: false
      t.jsonb :metadata, default: {}, null: false
      t.boolean :chargeable, default: true, null: false

      t.timestamps

      t.index :kind
      t.index [:resource_type, :resource_id]
    end

    create_table :active_billing_invoices do |t|
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.references :resource, polymorphic: true, null: false
      t.string :state, default: 'created', null: false
      t.string :external_invoice_id
      t.datetime :issued_at
      t.bigint :rps_number
      t.hstore :email_timestamps
      t.integer :amount_in_cents
      t.text :description
      t.string :payment_collected_medium, default: 'missing'
      t.string :nfe_number
      t.string :nfe_service_code

      t.timestamps

      t.index :uuid, unique: true
      t.index :external_invoice_id, unique: true
      t.index :state
    end

    create_table :active_billing_invoice_items do |t|
      t.references :billing_invoice, null: false, foreign_key: { to_table: :active_billing_invoices }
      t.references :usage, foreign_key: { to_table: :active_billing_usages }
      t.string :key, null: false
      t.text :description
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :price, precision: 10, scale: 2

      t.timestamps

      t.index [:usage_id, :billing_invoice_id], name: 'index_items_on_usage_and_invoice'
    end

    add_foreign_key :active_billing_charges, :active_billing_invoices, column: :invoice_id
  end
end
