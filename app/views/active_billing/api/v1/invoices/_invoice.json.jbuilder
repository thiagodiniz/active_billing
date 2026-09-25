json.call(invoice, :id, :uuid, :billing_id, :resource_type, :resource_id, :state,
          :description, :external_invoice_id, :issued_at, :payment_collected_medium,
          :discarded_at, :created_at, :updated_at)
json.amount_in_cents invoice.amount_in_cents&.cents
json.items invoice.items.order(:created_at),
           partial: "active_billing/api/v1/invoice_items/invoice_item", as: :invoice_item
