module ActiveBilling
  module Api
    module V1
      # Base for every JSON API controller. Enforces the `api_enabled` gate,
      # authenticates via `config.api_authorizer`, and maps domain/record errors
      # onto a consistent JSON envelope: { "error": { "code", "message", "details" } }.
      #
      # Override any controller (including this one) by generating a local copy —
      # see `rails g active_billing:api_base` / `:api_controller`. Host-app classes
      # of the same name take precedence over the engine's.
      class BaseController < ActionController::API
        before_action :ensure_api_enabled
        before_action :authenticate!

        rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
        rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
        rescue_from ActiveModel::ValidationError, with: :render_unprocessable
        rescue_from ActiveRecord::RecordNotUnique, with: :render_conflict
        rescue_from ActiveBilling::Error, with: :render_conflict
        rescue_from ActionController::ParameterMissing, with: :render_bad_request

        private

        def ensure_api_enabled
          head :not_found unless ActiveBilling.configuration.api_enabled
        end

        # Contract: config.api_authorizer is a callable `->(api_key, request) { scope }`.
        # It returns a truthy scope object when the key is valid, or a falsy value to reject.
        def authenticate!
          authorizer = ActiveBilling.configuration.api_authorizer
          if authorizer.nil?
            return render_error(:forbidden, "api_authorizer_not_configured",
                                I18n.t("active_billing.api.errors.api_authorizer_not_configured",
                                       default: "No api_authorizer is configured"))
          end

          @api_scope = authorizer.call(request.headers["X-Api-Key"], request)
          return if @api_scope

          render_error(:unauthorized, "unauthorized",
                       I18n.t("active_billing.api.errors.unauthorized",
                              default: "Invalid or missing API key"))
        end

        # Applies billable-entity scoping when the relation supports it (Billing, Usage,
        # Invoice, Charge). When the authorizer's scope exposes `billable_entity_type` and
        # `billable_entity_id` it is enforced and cannot be overridden by the client;
        # otherwise the optional query params are used as a filter.
        def scoped(relation)
          type, id = billable_entity_filter
          return relation unless type && id && relation.respond_to?(:for_billable_entity)

          relation.for_billable_entity(type, id)
        end

        def billable_entity_filter
          scope_type = api_scope_value(:billable_entity_type)
          scope_id = api_scope_value(:billable_entity_id)
          return [scope_type, scope_id] if scope_type.present? && scope_id.present?

          [params[:billable_entity_type].presence, params[:billable_entity_id].presence]
        end

        def api_scope_value(key)
          if @api_scope.respond_to?(key)
            @api_scope.public_send(key)
          elsif @api_scope.is_a?(Hash)
            @api_scope[key] || @api_scope[key.to_s]
          end
        end

        def render_error(status, code, message, details = nil)
          payload = { error: { code: code, message: message } }
          payload[:error][:details] = details if details.present?
          render json: payload, status: status
        end

        def render_not_found(error)
          render_error(:not_found, "not_found", error.message)
        end

        def render_unprocessable(error)
          record = error.try(:record)
          render_error(:unprocessable_entity, "validation_failed", error.message,
                       record&.errors&.messages)
        end

        def render_conflict(error)
          render_error(:conflict, "conflict", error.message)
        end

        def render_bad_request(error)
          render_error(:bad_request, "bad_request", error.message)
        end
      end
    end
  end
end
