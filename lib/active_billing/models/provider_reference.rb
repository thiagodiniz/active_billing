module ActiveBilling
  # Maps a local record (Plan, Billing, ...) to its counterpart on one provider.
  # A Plan mirrored to Stripe and Polar has two references, one per provider.
  class ProviderReference < ActiveRecord::Base
    belongs_to :record, polymorphic: true

    validates :provider, presence: true
    validates :external_id, presence: true
    validates :provider, uniqueness: { scope: %i[record_type record_id] }

    scope :for_provider, ->(name) { where(provider: name.to_s) }

    def self.lookup(provider, external_id)
      for_provider(provider).find_by(external_id: external_id.to_s)
    end

    def self.upsert_from(record, provider, result)
      reference = record.provider_references.find_or_initialize_by(provider: provider.to_s)
      reference.update!(external_id: result.external_id,
                        metadata: reference.metadata.merge(result.raw.deep_stringify_keys))
      reference
    end
  end
end
