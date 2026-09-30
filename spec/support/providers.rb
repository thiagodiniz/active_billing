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

module ProviderReferenceHelpers
  # Stores `external_id`/`metadata` for `provider` on `record` (as an adapter
  # result would) and returns the resulting `Providers::Reference`. Records that
  # are not persisted get an unsaved reference instead.
  def provider_reference(record, provider, external_id, metadata = {}, current: true)
    if record.persisted?
      result = ActiveBilling::Providers::Result.new(external_id: external_id, raw: metadata)
      record.store_provider_result!(provider, result, current: current)
      record.provider_reference_for(provider)
    else
      ActiveBilling::Providers::Reference.new(provider: provider, external_id: external_id, metadata: metadata)
    end
  end
end

RSpec.configure { |config| config.include ProviderReferenceHelpers }
