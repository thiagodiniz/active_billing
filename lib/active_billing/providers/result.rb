module ActiveBilling
  module Providers
    # Normalised return value of every adapter operation that touches a remote
    # object (customer, plan, subscription or payment).
    #
    #   external_id - the provider's identifier for the object
    #   status      - provider-agnostic status (see PAYMENT_STATUSES for payments)
    #   url         - hosted page the payer can be redirected to, when applicable
    #   raw         - the untouched provider payload, stored as metadata
    PAYMENT_STATUSES = %w[pending processing paid failed expired cancelled].freeze

    Result = Struct.new(:external_id, :status, :url, :raw, keyword_init: true) do
      def initialize(external_id:, status: nil, url: nil, raw: {})
        super(external_id: external_id.to_s, status: status&.to_s, url: url, raw: raw || {})
      end

      def paid?
        status == "paid"
      end
    end
  end
end
