module ActiveBilling
  module Api
    module V1
      class BillingsController < BaseController
        def index
          @billings = scoped(ActiveBilling::Billing.kept).order(created_at: :desc)
          render :index
        end

        def show
          @billing = find_billing
          render :show
        end

        def create
          @billing = ActiveBilling::Billing.create!(billing_params)
          render :show, status: :created
        end

        def update
          @billing = find_billing
          @billing.update!(billing_params)
          render :show
        end

        # Never physically deleted — logical (soft) delete only.
        def destroy
          find_billing.discard
          head :no_content
        end

        # PUT /billings/:id/plan — associate a plan (only while open).
        def plan
          @billing = find_billing
          @billing.associate_plan!(ActiveBilling::Plan.find(params.require(:plan_id)))
          render :show
        end

        # POST /billings/:id/finalization
        def finalization
          @billing = find_billing
          @billing.finalize!
          render :show
        end

        private

        def find_billing
          ActiveBilling::Billing.find(params[:id])
        end

        def billing_params
          params.require(:billing).permit(:plan_id, :billable_entity_type, :billable_entity_id,
                                          :period_start, :period_end, :state, metadata: {})
        end
      end
    end
  end
end
