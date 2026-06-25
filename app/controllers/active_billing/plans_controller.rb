module ActiveBilling
  class PlansController < PortalController
    before_action :require_billable_entity

    def show
      @billing = Billing.for_billable_entity(billable_entity_type, billable_entity_id)
                        .open.order(:created_at).last
      @plan = @billing&.plan
    end
  end
end
