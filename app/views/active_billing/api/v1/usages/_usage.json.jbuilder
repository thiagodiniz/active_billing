json.call(usage, :id, :uuid, :billable_entity_type, :billable_entity_id, :billing_id,
          :month, :closed_at, :metadata, :created_at, :updated_at)
json.closed usage.closed?
json.total_cost_in_cents usage.total_cost_in_cents&.cents
