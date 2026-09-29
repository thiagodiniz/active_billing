module ActiveBilling
  class PlansController < PortalController
    before_action :require_billable_entity

    def show
      @subscription = Subscription.for_billable_entity(billable_entity_type, billable_entity_id)
                                  .open.order(:created_at).last
      @plan = @subscription&.plan
    end
  end
end
