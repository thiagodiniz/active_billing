# This migration comes from active_billing (originally 20260924000001)
class CreateActiveBillingProviderTables < ActiveRecord::Migration[7.0]
  # Every record mirrored to a payment provider carries the same three columns:
  #   provider     - the provider currently in charge of the record
  #   provider_id  - the record's id on that provider
  #   provider_ids - ids/metadata on every provider it has ever been on, keyed by
  #                  provider name ({ "stripe" => { "id" => "prod_1", ... } }), so a
  #                  record moved between providers keeps its history
  SYNCED_TABLES = %i[active_billing_plans active_billing_billings active_billing_charges].freeze

  def change
    create_table :active_billing_provider_accounts do |t|
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.references :billable_entity, polymorphic: true, null: false, index: false
      t.string :provider, null: false
      t.string :provider_id
      t.jsonb :provider_ids, default: {}, null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps

      t.index :uuid, unique: true
      t.index [:billable_entity_type, :billable_entity_id],
              name: 'index_active_billing_provider_accounts_on_entity',
              unique: true
      t.index [:provider, :provider_id], name: 'index_active_billing_provider_accounts_on_provider_id'
    end

    SYNCED_TABLES.each do |table|
      change_table table do |t|
        t.string :provider
        t.string :provider_id
        t.jsonb :provider_ids, default: {}, null: false

        t.index [:provider, :provider_id], name: "index_#{table}_on_provider_id"
      end
    end

    change_table :active_billing_charges do |t|
      t.string :state, default: 'created', null: false
      t.string :payment_url
      t.datetime :paid_at
      t.datetime :failed_at
      t.datetime :expired_at
      t.jsonb :metadata, default: {}, null: false

      t.index :state
    end
  end
end
