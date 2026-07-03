require "discard"

require "active_billing/version"
require "active_billing/money"
require "active_billing/engine"

require "active_billing/concerns/chargeable"
require "active_billing/concerns/nfe_description"
require "active_billing/concerns/timestamp_store_accessor"

module ActiveBilling
  class Error < StandardError; end

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  class Configuration
    # api_enabled     — master switch for the standalone JSON API (mounted routes
    #                   respond 404 while false).
    # api_authorizer  — callable `->(api_key, request) { scope }` invoked on every API
    #                   request. Return a truthy scope object to authorize (falsy → 401).
    #                   When nil, the API rejects every request with 403.
    attr_accessor :currency,
                  :default_penalty,
                  :default_interest,
                  :default_cycle_interval,
                  :billing_entity_method,
                  :billable_entity_class,
                  :api_enabled,
                  :api_authorizer

    def initialize
      @currency               = :BRL
      @default_penalty        = 200
      @default_interest       = 100
      @default_cycle_interval = :monthly
      @billing_entity_method  = :billing_entity
      @billable_entity_class  = nil
      @api_enabled            = false
      @api_authorizer         = nil
    end
  end
end
