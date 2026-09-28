module ActiveBilling
  module Api
    module V1
      class PlansController < BaseController
        def index
          @plans = ActiveBilling::Plan.order(created_at: :desc)
          render :index
        end

        def show
          @plan = find_plan
          render :show
        end

        def create
          @plan = ActiveBilling::Plan.create!(plan_params)
          render :show, status: :created
        end

        def update
          @plan = find_plan
          @plan.update!(plan_params)
          render :show
        end

        # Hard delete only if the plan was never used; otherwise deactivate.
        def destroy
          @plan = find_plan
          if @plan.billings.exists?
            @plan.update!(active: false)
            render :show
          else
            @plan.destroy!
            head :no_content
          end
        end

        private

        def find_plan
          ActiveBilling::Plan.find(params[:id])
        end

        def plan_params
          params.require(:plan).permit(:name, :price_in_cents, :interval, :active,
                                       allowances: {}, metadata: {})
        end
      end
    end
  end
end
