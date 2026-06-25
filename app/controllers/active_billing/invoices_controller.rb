module ActiveBilling
  class InvoicesController < PortalController
    before_action :require_billable_entity, only: %i[index]

    def index
      @invoices = Invoice.for_billable_entity(billable_entity_type, billable_entity_id)
                         .order(created_at: :desc)
    end

    def show
      @invoice = Invoice.find(params[:id])
    end
  end
end
