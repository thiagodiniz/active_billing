module ActiveBilling
  class PortalController < ApplicationController
    helper_method :billable_entity_id, :billable_entity_type

    private

    def billable_entity_id
      current_billable_entity&.id
    end

    def billable_entity_type
      current_billable_entity&.class&.polymorphic_name
    end

    # Entity resolved by `config.portal_billable_entity` for the current request.
    def current_billable_entity
      return @current_billable_entity if defined?(@current_billable_entity)

      resolver = ActiveBilling.configuration.portal_billable_entity
      @current_billable_entity = resolver.respond_to?(:call) ? resolver.call(self) : nil
    end

    def require_billable_entity
      return render_portal_error("portal_not_configured", :forbidden) unless portal_configured?
      return if current_billable_entity.present?

      render_portal_error("missing_billable_entity", :bad_request)
    end

    def portal_configured?
      ActiveBilling.configuration.portal_billable_entity.respond_to?(:call)
    end

    def render_portal_error(key, status)
      render "active_billing/shared/portal_error", formats: [:html], status: status, locals: { key: key }
    end
  end
end
