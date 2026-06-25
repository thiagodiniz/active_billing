module ActiveBilling
  class UsagesController < PortalController
    before_action :require_billable_entity, only: %i[index]

    def index
      @usages = Usage.for_billable_entity(billable_entity_type, billable_entity_id)
                     .order(month: :desc)
    end

    def show
      @usage = Usage.find(params[:id])
    end
  end
end
