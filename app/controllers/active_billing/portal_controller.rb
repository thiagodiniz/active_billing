module ActiveBilling
  class PortalController < ApplicationController
    helper_method :billable_entity_id, :billable_entity_type, :current_scope_params

    private

    def billable_entity_id
      return current_billable_entity&.id if portal_billable_entity?

      params[:billable_entity_id].presence
    end

    def billable_entity_type
      return current_billable_entity&.class&.polymorphic_name if portal_billable_entity?

      params[:billable_entity_type].presence || ActiveBilling.configuration.billable_entity_class
    end

    # Params to carry through links so the billable entity stays in scope.
    def current_scope_params
      return {} if portal_billable_entity?

      { billable_entity_id: billable_entity_id, billable_entity_type: params[:billable_entity_type].presence }.compact
    end

    # Entity resolved by `config.portal_billable_entity` for the current request.
    # When the hook is configured the query params are ignored entirely.
    def current_billable_entity
      return @current_billable_entity if defined?(@current_billable_entity)

      @current_billable_entity = ActiveBilling.configuration.portal_billable_entity.call(self)
    end

    def portal_billable_entity?
      ActiveBilling.configuration.portal_billable_entity.respond_to?(:call)
    end

    def require_billable_entity
      return if billable_entity_id.present? && billable_entity_type.present?

      render "active_billing/shared/missing_billable_entity", formats: [:html], status: :bad_request
    end
  end
end
