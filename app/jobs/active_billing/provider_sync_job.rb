module ActiveBilling
  class ProviderSyncJob < ApplicationJob
    queue_as :active_billing

    retry_on Providers::ApiError, wait: :polynomially_longer, attempts: 5
    discard_on ActiveJob::DeserializationError

    def perform(record, operation)
      Providers::Synchronizer.perform(record, operation)
    end
  end
end
