require "discard"

require "active_billing/version"
require "active_billing/money"
require "active_billing/engine"
require "active_billing/invoice_pdf"

require "active_billing/concerns/nfe_description"
require "active_billing/concerns/timestamp_store_accessor"
require "active_billing/concerns/provider_syncable"

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
    # portal_billable_entity — callable `->(controller) { entity }` that resolves the
    #                   billable entity the portal is scoped to (e.g. from the signed-in
    #                   user). Required for the portal: when nil every portal request
    #                   responds 403; a nil result responds 400.
    attr_accessor :currency,
                  :default_penalty,
                  :default_interest,
                  :default_cycle_interval,
                  :billing_entity_method,
                  :billable_entity_class,
                  :invoice_description,
                  :parent_controller,
                  :portal_billable_entity,
                  :api_enabled,
                  :api_authorizer,
                  :company,
                  :invoice_recipient,
                  :invoice_pdf_footer,
                  :invoice_pdf_page_size,
                  :providers,
                  :default_provider,
                  :provider_resolver,
                  :provider_sync_enabled,
                  :provider_sync_async

    def initialize
      @currency               = :BRL
      @default_penalty        = 200
      @default_interest       = 100
      @default_cycle_interval = :monthly
      @billing_entity_method  = :billing_entity
      @billable_entity_class  = nil
      @invoice_description    = nil
      @parent_controller      = "ActionController::Base"
      @portal_billable_entity = nil
      @api_enabled            = false
      @api_authorizer         = nil
      @company                = nil
      @invoice_recipient      = nil
      @invoice_pdf_footer     = nil
      @invoice_pdf_page_size  = "A4"
      @providers              = {}
      @default_provider       = nil
      @provider_resolver      = nil
      @provider_sync_enabled  = true
      @provider_sync_async    = true
    end

    # Registers settings for a provider adapter, e.g.
    #   config.provider :stripe, api_key: ENV["STRIPE_API_KEY"], webhook_secret: ENV["STRIPE_WEBHOOK_SECRET"]
    def provider(name, **settings)
      providers[name.to_sym] = settings
    end
  end
end

require "active_billing/providers"
require "active_billing/providers/synchronizer"
require "active_billing/providers/webhook_processor"
