json.call(plan, :id, :uuid, :name, :interval, :active, :allowances, :metadata, :created_at, :updated_at)
json.price_in_cents plan.price_in_cents&.cents
