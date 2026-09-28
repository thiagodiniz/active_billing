module ActiveBilling
  # Ties a billable entity to the payment provider that currently handles it.
  # `provider_id` is the entity's customer id on that provider; `provider_ids`
  # keeps the customer ids on every provider the entity has been on, so a move
  # between providers keeps the old ids around.
  class ProviderAccount < ActiveRecord::Base
    include Concerns::ProviderSyncable

    belongs_to :billable_entity, polymorphic: true

    validates :provider, presence: true
    validates :billable_entity_id, uniqueness: { scope: :billable_entity_type }
    validate :provider_must_be_registered

    scope :for_billable_entity, ->(type, id) {
      where(billable_entity_type: type, billable_entity_id: id)
    }

    sync_with_provider create: :create_customer, update: :update_customer, if: :synced_attributes_changed?

    alias_attribute :external_customer_id, :provider_id

    def self.current_for(entity)
      return if entity.nil?

      for_billable_entity(entity.class.name, entity.id).first
    end

    def adapter
      Providers.build(provider)
    end

    private

    def synced_attributes_changed?
      saved_changes.keys.intersect?(%w[provider metadata])
    end

    def provider_must_be_registered
      return if provider.blank? || Providers.registered?(provider)

      errors.add(:provider, :inclusion, message: "is not a registered provider")
    end
  end
end
