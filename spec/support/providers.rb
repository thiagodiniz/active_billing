# Examples tagged `:providers` run with the in-memory Test adapter configured as
# `:test` and synchronous syncing, so callbacks hit the adapter inline.
RSpec.configure do |config|
  config.around(:each, :providers) do |example|
    configuration = ActiveBilling.configuration
    original = configuration.dup

    configuration.providers = { test: { webhook_secret: "whsec_test" } }
    configuration.default_provider = nil
    configuration.provider_resolver = nil
    configuration.provider_sync_enabled = true
    configuration.provider_sync_async = false
    ActiveBilling::Providers::Test.reset!

    example.run
  ensure
    ActiveBilling.configuration = original
    ActiveBilling::Providers::Test.reset!
  end
end
