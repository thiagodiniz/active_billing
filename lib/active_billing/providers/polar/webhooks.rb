require "base64"
require "openssl"
require "time"

module ActiveBilling
  module Providers
    class Polar < Base
      # Standard Webhooks header lookup, signing and event helpers shared by
      # `verify_webhook!` / `parse_webhook`.
      module Webhooks
        private

        def header(headers, name)
          return if headers.nil?

          key = headers.keys.find do |candidate|
            candidate.to_s.tr("_", "-").casecmp?(name) || candidate.to_s.casecmp?("HTTP_#{name.tr('-', '_')}")
          end
          key && headers[key]
        end

        def webhook_type_for(type, data)
          case type
          when "checkout.updated", "checkout.expired"
            status = CHECKOUT_STATUSES[data["status"]]
            status ? :"payment_#{status}" : :ignored
          when "order.paid" then :payment_paid
          else SUBSCRIPTION_EVENTS.fetch(type, :ignored)
          end
        end

        # Subscriptions and orders are keyed by the checkout that created them, since
        # that is the id `create_subscription` / `create_payment` hand back.
        def webhook_external_id(type, data)
          return data["id"] if type.to_s.start_with?("checkout.")

          data["checkout_id"] || data["id"]
        end

        def webhook_headers(headers)
          values = %w[webhook-id webhook-timestamp webhook-signature].map { |name| header(headers, name) }
          raise InvalidWebhookSignature, "polar: missing webhook headers" if values.any?(&:blank?)

          values
        end

        def signatures_in(header_value)
          header_value.split.filter_map { |part| part.split(",", 2).last if part.start_with?("v1,") }
        end

        def secure_compare(left, right)
          ActiveSupport::SecurityUtils.secure_compare(left, right)
        end

        def fresh?(timestamp)
          (Time.now.to_i - timestamp.to_i).abs <= SIGNATURE_TOLERANCE
        end

        def signing_keys
          secret = setting!(:webhook_secret).to_s
          keys = [secret]
          begin
            keys << Base64.strict_decode64(secret.delete_prefix("whsec_"))
          rescue ArgumentError
            keys
          end
          keys
        end

        def sign(key, message)
          Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", key, message))
        end

        def parse_time(value)
          return if value.blank?

          Time.iso8601(value)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
