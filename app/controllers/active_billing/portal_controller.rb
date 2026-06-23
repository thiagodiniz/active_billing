module ActiveBilling
  class PortalController < ApplicationController
    helper_method :billable_entity_id, :billable_entity_type, :current_scope_params

    private

    def billable_entity_id
      params[:billable_entity_id].presence
    end

    def billable_entity_type
      params[:billable_entity_type].presence || ActiveBilling.configuration.billable_entity_class
    end

    # Params to carry through links so the billable entity stays in scope.
    def current_scope_params
      { billable_entity_id: billable_entity_id, billable_entity_type: params[:billable_entity_type].presence }.compact
    end

    def require_billable_entity
      return if billable_entity_id.present? && billable_entity_type.present?

      render "active_billing/shared/missing_billable_entity", status: :bad_request
    end
  end
end
