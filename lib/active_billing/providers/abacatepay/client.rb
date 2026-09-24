require "net/http"
require "json"

module ActiveBilling
  module Providers
    class Abacatepay < Base
      # Minimal JSON client for https://api.abacatepay.com/v2. Every response is
      # wrapped as `{ "data": ..., "success": true, "error": null }`; `#post`/`#get`
      # return the unwrapped `data` and raise ApiError on HTTP or API errors.
      class Client
        BASE_URL = "https://api.abacatepay.com/v2".freeze

        def initialize(api_key:, base_url: nil, provider_name: :abacatepay)
          @api_key = api_key
          @base_url = base_url || BASE_URL
          @provider_name = provider_name
        end

        def post(path, body)
          request = Net::HTTP::Post.new(uri_for(path))
          request.body = JSON.generate(body)
          perform(request)
        end

        def get(path, params)
          perform(Net::HTTP::Get.new(uri_for(path, params)))
        end

        private

        attr_reader :api_key, :base_url, :provider_name

        def uri_for(path, params = nil)
          uri = URI.parse("#{base_url}#{path}")
          uri.query = URI.encode_www_form(params) if params
          uri
        end

        def perform(request)
          request["Authorization"] = "Bearer #{api_key}"
          request["Content-Type"] = "application/json"
          request["Accept"] = "application/json"

          uri = request.uri
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
          unwrap(response, parse_body(response))
        end

        def parse_body(response)
          JSON.parse(response.body.to_s)
        rescue JSON::ParserError
          { "error" => response.body }
        end

        def unwrap(response, body)
          error = body["error"] if body.is_a?(Hash)
          return body["data"] || body if response.is_a?(Net::HTTPSuccess) && error.blank?

          message = error.presence || "#{provider_name}: request failed (HTTP #{response.code})"
          raise ApiError.new(message, code: response.code.to_i, response: body)
        end
      end
    end
  end
end
