module ActiveBilling
  module Api
    module V1
      class UsagesController < BaseController
        def index
          @usages = scoped(ActiveBilling::Usage.all).order(created_at: :desc)
          render :index
        end

        def show
          @usage = find_usage
          render :show
        end

        # One usage per billing cycle is enforced by the unique index on
        # [billable_entity_type, billable_entity_id, month] → RecordNotUnique → 409.
        def create
          @usage = ActiveBilling::Usage.create!(usage_params)
          render :show, status: :created
        end

        def update
          @usage = find_usage
          @usage.update!(usage_params)
          render :show
        end

        # Deletable only when empty (no events).
        def destroy
          usage = find_usage
          raise ActiveBilling::Error, "usage has events and cannot be deleted" if usage.events.exists?

          usage.destroy!
          head :no_content
        end

        # POST /usages/:id/closure
        def closure
          @usage = find_usage
          @usage.close!
          render :show
        end

        private

        def find_usage
          scoped(ActiveBilling::Usage.all).find(params[:id])
        end

        def usage_params
          params.require(:usage).permit(:billable_entity_type, :billable_entity_id, :month,
                                        :billing_id, :total_cost_in_cents, metadata: {})
        end
      end
    end
  end
end
