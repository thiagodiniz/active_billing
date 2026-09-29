module ActiveBilling
  module Api
    module V1
      class SubscriptionsController < BaseController
        def index
          @subscriptions = scoped(ActiveBilling::Subscription.kept).order(created_at: :desc)
          render :index
        end

        def show
          @subscription = find_billing
          render :show
        end

        def create
          @subscription = ActiveBilling::Subscription.create!(billing_params)
          render :show, status: :created
        end

        def update
          @subscription = find_billing
          raise ActiveBilling::Error, "subscription cannot be changed after finalization" unless @subscription.open?

          @subscription.update!(billing_params)
          render :show
        end

        # Never physically deleted — logical (soft) delete only.
        def destroy
          find_billing.discard
          head :no_content
        end

        # PUT /subscriptions/:id/plan — associate a plan (only while open).
        def plan
          @subscription = find_billing
          @subscription.associate_plan!(ActiveBilling::Plan.find(params.require(:plan_id)))
          render :show
        end

        # POST /subscriptions/:id/finalization
        def finalization
          @subscription = find_billing
          @subscription.finalize!
          render :show
        end

        private

        def find_billing
          scoped(ActiveBilling::Subscription.kept).find(params[:id])
        end

        # `state` is never mass-assignable (use /finalization). `plan_id` is only accepted
        # on create; afterwards plans change via PUT /subscriptions/:id/plan so the snapshot
        # stays consistent.
        def billing_params
          permitted = %i[billable_entity_type billable_entity_id period_start period_end]
          permitted << :plan_id if action_name == "create"
          params.require(:subscription).permit(*permitted, metadata: {})
        end
      end
    end
  end
end
