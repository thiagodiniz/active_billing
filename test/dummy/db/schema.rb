# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_24_211544) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_billing_billings", force: :cascade do |t|
    t.bigint "billable_entity_id", null: false
    t.string "billable_entity_type", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.date "period_end"
    t.date "period_start"
    t.jsonb "plan_allowances", default: {}, null: false
    t.bigint "plan_id"
    t.string "plan_name"
    t.integer "plan_price_in_cents"
    t.string "state", default: "open", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["billable_entity_type", "billable_entity_id"], name: "index_active_billing_billings_on_billable_entity"
    t.index ["plan_id"], name: "index_active_billing_billings_on_plan_id"
    t.index ["state"], name: "index_active_billing_billings_on_state"
    t.index ["uuid"], name: "index_active_billing_billings_on_uuid", unique: true
  end

  create_table "active_billing_charges", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_interest"
    t.integer "default_penalty"
    t.bigint "invoice_id"
    t.bigint "resource_id", null: false
    t.string "resource_type", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.string "state", default: "created", null: false
    t.string "provider"
    t.string "external_id"
    t.string "payment_url"
    t.datetime "paid_at"
    t.datetime "failed_at"
    t.datetime "expired_at"
    t.jsonb "metadata", default: {}, null: false
    t.index ["invoice_id"], name: "index_active_billing_charges_on_invoice_id"
    t.index ["provider", "external_id"], name: "index_active_billing_charges_on_provider_and_external_id", unique: true
    t.index ["resource_type", "resource_id"], name: "index_active_billing_charges_on_resource"
    t.index ["state"], name: "index_active_billing_charges_on_state"
    t.index ["uuid"], name: "index_active_billing_charges_on_uuid", unique: true
  end

  create_table "active_billing_events", force: :cascade do |t|
    t.bigint "billing_usage_id", null: false
    t.boolean "chargeable", default: true, null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["billing_usage_id"], name: "index_active_billing_events_on_billing_usage_id"
    t.index ["kind"], name: "index_active_billing_events_on_kind"
    t.index ["resource_type", "resource_id"], name: "index_active_billing_events_on_resource"
    t.index ["resource_type", "resource_id"], name: "index_active_billing_events_on_resource_type_and_resource_id"
  end

  create_table "active_billing_invoice_items", force: :cascade do |t|
    t.bigint "billing_invoice_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.decimal "price", precision: 10, scale: 2
    t.integer "quantity", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "usage_id"
    t.index ["billing_invoice_id"], name: "index_active_billing_invoice_items_on_billing_invoice_id"
    t.index ["usage_id", "billing_invoice_id"], name: "index_items_on_usage_and_invoice"
    t.index ["usage_id"], name: "index_active_billing_invoice_items_on_usage_id"
  end

  create_table "active_billing_invoices", force: :cascade do |t|
    t.integer "amount_in_cents"
    t.bigint "billing_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.hstore "email_timestamps"
    t.string "external_invoice_id"
    t.datetime "issued_at"
    t.string "nfe_number"
    t.string "nfe_service_code"
    t.string "payment_collected_medium", default: "missing"
    t.bigint "resource_id", null: false
    t.string "resource_type", null: false
    t.bigint "rps_number"
    t.string "state", default: "created", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["billing_id"], name: "index_active_billing_invoices_on_billing_id"
    t.index ["external_invoice_id"], name: "index_active_billing_invoices_on_external_invoice_id", unique: true
    t.index ["resource_type", "resource_id"], name: "index_active_billing_invoices_on_resource"
    t.index ["state"], name: "index_active_billing_invoices_on_state"
    t.index ["uuid"], name: "index_active_billing_invoices_on_uuid", unique: true
  end

  create_table "active_billing_plans", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "allowances", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "interval", default: "monthly", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.integer "price_in_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["active"], name: "index_active_billing_plans_on_active"
    t.index ["uuid"], name: "index_active_billing_plans_on_uuid", unique: true
  end

  create_table "active_billing_provider_accounts", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.string "billable_entity_type", null: false
    t.bigint "billable_entity_id", null: false
    t.string "provider", null: false
    t.string "external_customer_id"
    t.boolean "active", default: true, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["billable_entity_type", "billable_entity_id", "provider"], name: "index_active_billing_provider_accounts_on_entity", unique: true
    t.index ["billable_entity_type", "billable_entity_id"], name: "index_active_billing_provider_accounts_on_billable_entity"
    t.index ["provider", "external_customer_id"], name: "index_active_billing_provider_accounts_on_customer"
    t.index ["uuid"], name: "index_active_billing_provider_accounts_on_uuid", unique: true
  end

  create_table "active_billing_provider_references", force: :cascade do |t|
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.string "provider", null: false
    t.string "external_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "external_id"], name: "index_active_billing_provider_references_on_external_id"
    t.index ["record_type", "record_id", "provider"], name: "index_active_billing_provider_references_on_record_provider", unique: true
    t.index ["record_type", "record_id"], name: "index_active_billing_provider_references_on_record"
  end

  create_table "active_billing_usages", force: :cascade do |t|
    t.bigint "billable_entity_id", null: false
    t.string "billable_entity_type", null: false
    t.bigint "billing_id"
    t.datetime "created_at", null: false
    t.hstore "email_timestamps"
    t.jsonb "metadata", default: {}, null: false
    t.date "month", null: false
    t.integer "total_cost_in_cents", default: 0
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["billable_entity_type", "billable_entity_id", "month"], name: "index_active_billing_usages_on_entity_and_month", unique: true
    t.index ["billable_entity_type", "billable_entity_id"], name: "index_active_billing_usages_on_billable_entity"
    t.index ["billing_id"], name: "index_active_billing_usages_on_billing_id"
    t.index ["month"], name: "index_active_billing_usages_on_month"
    t.index ["uuid"], name: "index_active_billing_usages_on_uuid", unique: true
  end

  create_table "stores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_billing_billings", "active_billing_plans", column: "plan_id"
  add_foreign_key "active_billing_charges", "active_billing_invoices", column: "invoice_id"
  add_foreign_key "active_billing_events", "active_billing_usages", column: "billing_usage_id"
  add_foreign_key "active_billing_invoice_items", "active_billing_invoices", column: "billing_invoice_id"
  add_foreign_key "active_billing_invoice_items", "active_billing_usages", column: "usage_id"
  add_foreign_key "active_billing_invoices", "active_billing_billings", column: "billing_id"
  add_foreign_key "active_billing_usages", "active_billing_billings", column: "billing_id"
end
