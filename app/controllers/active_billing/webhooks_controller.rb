module ActiveBilling
  # Receives provider webhooks at POST /webhooks/:provider. Signature verification
  # is delegated to the adapter, so the endpoint is public and skips CSRF.
  class WebhooksController < ActiveBilling.configuration.parent_controller.constantize
    skip_forgery_protection if respond_to?(:skip_forgery_protection)

    rescue_from Providers::UnknownProvider, with: :render_not_found
    rescue_from Providers::InvalidWebhookSignature, with: :render_unauthorized

    def create
      event = Providers::WebhookProcessor.new(params[:provider]).call(request.raw_post, webhook_headers)
      render json: { received: true, type: event.type }, status: :ok
    end

    private

    def webhook_headers
      request.headers.env.each_with_object({ "QUERY_STRING" => request.query_string }) do |(key, value), headers|
        next unless key.start_with?("HTTP_")

        headers[key.delete_prefix("HTTP_").split("_").map(&:capitalize).join("-")] = value
      end
    end

    def render_not_found
      head :not_found
    end

    def render_unauthorized(error)
      render json: { error: error.message }, status: :unauthorized
    end
  end
end
