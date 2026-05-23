require "active_billing/version"
require "active_billing/engine"

require "active_billing/concerns/chargeable"
require "active_billing/concerns/nfe_description"
require "active_billing/concerns/currency_attribute"
require "active_billing/concerns/timestamp_store_accessor"

module ActiveBilling
  class Error < StandardError; end

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor :currency,
                  :default_penalty,
                  :default_interest,
                  :default_cycle_interval,
                  :billing_entity_method,
                  :api_enabled,
                  :api_authorizer

    def initialize
      @currency               = :BRL
      @default_penalty        = 200
      @default_interest       = 100
      @default_cycle_interval = :monthly
      @billing_entity_method  = :billing_entity
      @api_enabled            = false
      @api_authorizer         = nil
    end
  end
end
