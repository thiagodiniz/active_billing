module ActiveBilling
  module Api
    module V1
      class ChargesController < BaseController
        def index
          @charges = scoped(ActiveBilling::Charge.kept).order(created_at: :desc)
          render :index
        end

        def show
          @charge = find_charge
          render :show
        end

        def create
          @charge = ActiveBilling::Charge.create!(charge_params)
          render :show, status: :created
        end

        def update
          @charge = find_charge
          @charge.update!(charge_params)
          render :show
        end

        # Never physically deleted — logical (soft) delete only.
        def destroy
          find_charge.discard
          head :no_content
        end

        # POST /charges/:id/payment — marks the charge paid. Requires the Charge state
        # machine (created → processing → paid / failed / expired), which is on the
        # roadmap; until it ships this endpoint reports 501.
        def payment
          render_error(:not_implemented, "not_implemented",
                       "Charge payment requires the Charge state machine, which is on the roadmap")
        end

        private

        def find_charge
          ActiveBilling::Charge.find(params[:id])
        end

        def charge_params
          params.require(:charge).permit(:invoice_id, :resource_type, :resource_id,
                                         :default_penalty, :default_interest)
        end
      end
    end
  end
end
