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
          raise ActiveBilling::Error, "billing cannot be changed after finalization" unless @billing.open?

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
          scoped(ActiveBilling::Billing.kept).find(params[:id])
        end

        # `state` is never mass-assignable (use /finalization). `plan_id` is only accepted
        # on create; afterwards plans change via PUT /billings/:id/plan so the snapshot
        # stays consistent.
        def billing_params
          permitted = %i[billable_entity_type billable_entity_id period_start period_end]
          permitted << :plan_id if action_name == "create"
          params.require(:billing).permit(*permitted, metadata: {})
        end
      end
    end
  end
end
