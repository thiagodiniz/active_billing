require "net/http"
require "json"

module ActiveBilling
  module Providers
    class Polar < Base
      # Minimal JSON client over Net::HTTP; every non-2xx response becomes ApiError.
      class Client
        attr_reader :api_key, :base_url

        def initialize(api_key, base_url)
          @api_key = api_key
          @base_url = base_url
        end

        def get(path)
          request(Net::HTTP::Get.new(uri_for(path)))
        end

        def post(path, body)
          request(Net::HTTP::Post.new(uri_for(path)), body)
        end

        def patch(path, body)
          request(Net::HTTP::Patch.new(uri_for(path)), body)
        end

        private

        def uri_for(path)
          URI.parse("#{base_url}#{path}")
        end

        def request(req, body = nil)
          req["Authorization"] = "Bearer #{api_key}"
          req["Accept"] = "application/json"
          if body
            req["Content-Type"] = "application/json"
            req.body = JSON.generate(body)
          end

          uri = req.uri
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(req) }
          handle(response)
        end

        def handle(response)
          payload = parse_body(response.body)
          return payload if response.is_a?(Net::HTTPSuccess)

          raise ApiError.new(error_message(response, payload), code: error_code(response, payload), response: payload)
        end

        def parse_body(body)
          return {} if body.blank?

          JSON.parse(body)
        rescue JSON::ParserError
          { "raw" => body }
        end

        def error_code(response, payload)
          (payload.is_a?(Hash) && payload["error"]) || response.code
        end

        def error_message(response, payload)
          detail = payload.is_a?(Hash) ? payload["detail"] : nil
          if detail.is_a?(Array)
            detail = detail.map do |error|
              "#{Array(error['loc']).join('.')}: #{error['msg']}"
            end.join("; ")
          end
          "polar: HTTP #{response.code} #{detail.presence || response.message}".strip
        end
      end
    end
  end
end
