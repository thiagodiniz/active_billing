ActiveBilling.configure do |config|
  # Currency used when formatting monetary amounts.
  config.currency = :BRL

  # Default late-payment penalty and interest, in cents.
  config.default_penalty  = 200
  config.default_interest = 100

  # Default billing cycle interval.
  config.default_cycle_interval = :monthly

  # Method the host app exposes to resolve the entity that receives payments.
  config.billing_entity_method = :billing_entity

  # Default polymorphic type for portal pages when billable_entity_type is not
  # passed as a query param, e.g. "Store" or "Organization".
  config.billable_entity_class = nil
end
