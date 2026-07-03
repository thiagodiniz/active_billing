module ActiveBilling
  module Api
    module V1
      # Events are append-only: create/read/destroy, no update.
      class EventsController < BaseController
        def index
          @events = ActiveBilling::Event.order(created_at: :desc)
          @events = @events.where(billing_usage_id: params[:billing_usage_id]) if params[:billing_usage_id].present?
          render :index
        end

        def show
          @event = ActiveBilling::Event.find(params[:id])
          render :show
        end

        def create
          @event = ActiveBilling::Event.create!(event_params)
          render :show, status: :created
        end

        def destroy
          ActiveBilling::Event.find(params[:id]).destroy!
          head :no_content
        end

        private

        def event_params
          params.require(:event).permit(:billing_usage_id, :kind, :chargeable,
                                        :resource_type, :resource_id, metadata: {})
        end
      end
    end
  end
end
