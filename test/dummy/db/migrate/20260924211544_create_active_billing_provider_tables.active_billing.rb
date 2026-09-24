# This migration comes from active_billing (originally 20260924000001)
class CreateActiveBillingProviderTables < ActiveRecord::Migration[7.0]
  def change
    create_table :active_billing_provider_accounts do |t|
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.references :billable_entity, polymorphic: true, null: false
      t.string :provider, null: false
      t.string :external_customer_id
      t.boolean :active, default: true, null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps

      t.index :uuid, unique: true
      t.index [:billable_entity_type, :billable_entity_id, :provider],
              name: 'index_active_billing_provider_accounts_on_entity',
              unique: true
      t.index [:provider, :external_customer_id],
              name: 'index_active_billing_provider_accounts_on_customer'
    end

    create_table :active_billing_provider_references do |t|
      t.references :record, polymorphic: true, null: false
      t.string :provider, null: false
      t.string :external_id, null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps

      t.index [:record_type, :record_id, :provider],
              name: 'index_active_billing_provider_references_on_record_provider',
              unique: true
      t.index [:provider, :external_id],
              name: 'index_active_billing_provider_references_on_external_id'
    end

    change_table :active_billing_charges do |t|
      t.string :state, default: 'created', null: false
      t.string :provider
      t.string :external_id
      t.string :payment_url
      t.datetime :paid_at
      t.datetime :failed_at
      t.datetime :expired_at
      t.jsonb :metadata, default: {}, null: false

      t.index :state
      t.index [:provider, :external_id], unique: true
    end
  end
end
