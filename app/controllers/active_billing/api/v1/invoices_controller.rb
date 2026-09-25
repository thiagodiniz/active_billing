module ActiveBilling
  module Api
    module V1
      class InvoicesController < BaseController
        def index
          @invoices = scoped(ActiveBilling::Invoice.kept).order(created_at: :desc)
          render :index
        end

        def show
          @invoice = find_invoice
          render :show
        end

        def create
          @invoice = ActiveBilling::Invoice.create!(invoice_params)
          render :show, status: :created
        end

        # Attribute updates are only allowed while the invoice is still issuable.
        def update
          @invoice = find_invoice
          raise ActiveBilling::Error, "invoice cannot be changed after issuing" unless @invoice.issuable?

          @invoice.update!(invoice_params)
          render :show
        end

        # Never physically deleted — logical (soft) delete only.
        def destroy
          find_invoice.discard
          head :no_content
        end

        # POST /invoices/:id/issuance
        def issuance
          @invoice = find_invoice
          @invoice.issue!
          render :show
        end

        # POST /invoices/:id/cancellation
        def cancellation
          @invoice = find_invoice
          @invoice.cancel!
          render :show
        end

        private

        def find_invoice
          scoped(ActiveBilling::Invoice.kept).find(params[:id])
        end

        # `state` is never mass-assignable (use /issuance and /cancellation).
        def invoice_params
          params.require(:invoice).permit(:billing_id, :resource_type, :resource_id,
                                          :description, :amount_in_cents, :external_invoice_id,
                                          :payment_collected_medium, add_usages_ids: [])
        end
      end
    end
  end
end
