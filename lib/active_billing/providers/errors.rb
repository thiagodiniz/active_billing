module ActiveBilling
  module Providers
    class Error < ActiveBilling::Error; end

    class UnknownProvider < Error
      def initialize(name)
        super("unknown payment provider: #{name}")
      end
    end

    class NotSupported < Error
      def initialize(provider, operation)
        super("#{provider} does not support #{operation}")
      end
    end

    class ConfigurationError < Error; end

    # Raised when the remote API rejects a request. `code` carries the
    # provider-specific error code and `response` the raw payload, if any.
    class ApiError < Error
      attr_reader :code, :response

      def initialize(message, code: nil, response: nil)
        @code = code
        @response = response
        super(message)
      end
    end

    class InvalidWebhookSignature < Error; end
  end
end
