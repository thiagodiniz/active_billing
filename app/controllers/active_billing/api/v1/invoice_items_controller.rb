module ActiveBilling
  module Api
    module V1
      # Nested under invoices: /invoices/:invoice_id/items. Writes are rejected once
      # the parent invoice is issued (items become immutable).
      class InvoiceItemsController < BaseController
        def index
          @items = invoice.items.order(:created_at)
          render :index
        end

        def show
          @item = invoice.items.find(params[:id])
          render :show
        end

        def create
          guard_issuable!
          @item = invoice.items.create!(item_params)
          render :show, status: :created
        end

        def update
          guard_issuable!
          @item = invoice.items.find(params[:id])
          @item.update!(item_params)
          render :show
        end

        def destroy
          guard_issuable!
          invoice.items.find(params[:id]).destroy!
          head :no_content
        end

        private

        def invoice
          @invoice ||= ActiveBilling::Invoice.find(params[:invoice_id])
        end

        def guard_issuable!
          raise ActiveBilling::Error, "invoice items cannot be changed after issuing" unless invoice.issuable?
        end

        def item_params
          params.require(:item).permit(:key, :description, :quantity, :unit_price, :usage_id)
        end
      end
    end
  end
end
