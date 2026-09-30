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

module ActiveBilling
  module Providers
    # A record's identity on one provider, read from its `provider_ids` column.
    # `metadata` holds whatever the adapter returned alongside the id (e.g. Stripe's
    # price id next to the product id).
    Reference = Struct.new(:provider, :external_id, :metadata, keyword_init: true) do
      def initialize(provider:, external_id:, metadata: {})
        super(provider: provider.to_s, external_id: external_id.to_s, metadata: (metadata || {}).deep_stringify_keys)
      end
    end
  end
end
