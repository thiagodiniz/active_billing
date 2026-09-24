require "openssl"
require "base64"
require "rack/utils"

module ActiveBilling
  module Providers
    class Abacatepay < Base
      # Webhook authentication and parsing. AbacatePay authenticates deliveries with
      # the `webhookSecret` query parameter configured on the dashboard and signs the
      # raw body with HMAC-SHA256 in `X-Webhook-Signature` (base64) using a key
      # published in the docs.
      module Webhooks
        SIGNATURE_HEADER = "X-Webhook-Signature".freeze
        SIGNATURE_KEY = "abc_dev_Xy7hW9mL2pQ3rT4vB5nC6dF8gH1jK2mN3pQ4rS5tU6vW7xY8zA9bC0dE1fG2hI3jK4lM5nO6pQ7r".freeze

        PAYMENT_EVENTS = {
          "transparent.completed" => :payment_paid,
          "transparent.refunded" => :payment_cancelled,
          "checkout.completed" => :payment_paid,
          "checkout.refunded" => :payment_cancelled
        }.freeze

        SUBSCRIPTION_EVENTS = {
          "subscription.completed" => :subscription_created,
          "subscription.trial_started" => :subscription_created,
          "subscription.renewed" => :subscription_updated,
          "subscription.plan_changed" => :subscription_updated,
          "subscription.payment_failed" => :subscription_updated,
          "subscription.cancelled" => :subscription_cancelled
        }.freeze

        def verify_webhook!(payload, headers)
          verify_secret!(setting!(:webhook_secret), headers)
          verify_signature!(payload, headers[SIGNATURE_HEADER])
        end

        def parse_webhook(payload, _headers)
          body = JSON.parse(payload.to_s)
          event = body["event"].to_s
          type = PAYMENT_EVENTS[event] || SUBSCRIPTION_EVENTS[event]
          return WebhookEvent.new(type: :ignored, raw: body) if type.nil?

          WebhookEvent.new(type: type, external_id: webhook_external_id(event, body["data"] || {}),
                           occurred_at: parse_time(body["createdAt"]), raw: body)
        rescue JSON::ParserError
          WebhookEvent.new(type: :ignored, raw: { "payload" => payload.to_s })
        end

        private

        def verify_secret!(secret, headers)
          given = headers["webhookSecret"] || Rack::Utils.parse_query(headers["QUERY_STRING"].to_s)["webhookSecret"]
          return if Rack::Utils.secure_compare(secret.to_s, given.to_s)

          raise InvalidWebhookSignature, "#{provider_name}: invalid webhookSecret"
        end

        def verify_signature!(payload, signature)
          return if signature.nil? || setting(:verify_signature) == false

          key = setting(:signature_key) || SIGNATURE_KEY
          expected = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", key, payload.to_s))
          return if Rack::Utils.secure_compare(expected, signature.to_s)

          raise InvalidWebhookSignature, "#{provider_name}: invalid #{SIGNATURE_HEADER}"
        end

        # Subscription references are keyed by the checkout id returned from
        # create_subscription; the `subs_` id only appears once the checkout is paid.
        def webhook_external_id(event, data)
          if PAYMENT_EVENTS.key?(event)
            (data["transparent"] || data["checkout"] || {})["id"]
          else
            data.dig("checkout", "id") || data.dig("subscription", "id")
          end
        end

        def parse_time(value)
          Time.zone.parse(value.to_s) if value.present?
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
