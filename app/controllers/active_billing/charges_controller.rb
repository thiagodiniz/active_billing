module ActiveBilling
  class ChargesController < PortalController
    before_action :require_billable_entity, only: %i[index show]

    def index
      @charges = Charge.for_billable_entity(billable_entity_type, billable_entity_id)
                       .order(created_at: :desc)
    end

    def show
      @charge = Charge.for_billable_entity(billable_entity_type, billable_entity_id).find(params[:id])
    end
  end
end
