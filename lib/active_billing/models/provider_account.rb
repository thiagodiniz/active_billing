module ActiveBilling
  # Binds a billable entity to the payment provider it is billed through. An entity
  # may hold one account per provider; the active one decides which adapter the
  # engine uses for its subscriptions and payments.
  class ProviderAccount < ActiveRecord::Base
    include Concerns::ProviderSyncable

    belongs_to :billable_entity, polymorphic: true

    validates :provider, presence: true
    validates :provider, uniqueness: { scope: %i[billable_entity_type billable_entity_id] }
    validate :provider_must_be_registered

    scope :active, -> { where(active: true) }
    scope :for_provider, ->(name) { where(provider: name.to_s) }
    scope :for_billable_entity, ->(type, id) { where(billable_entity_type: type, billable_entity_id: id) }

    sync_with_provider create: :create_customer, update: :update_customer, if: :synced_attributes_changed?

    def self.current_for(entity)
      return if entity.nil?

      for_billable_entity(entity.class.name, entity.id).active.order(:updated_at).last
    end

    def adapter
      Providers.build(provider)
    end

    def synced?
      external_customer_id.present?
    end

    private

    def synced_attributes_changed?
      saved_change_to_active? || saved_change_to_metadata?
    end

    def provider_must_be_registered
      return if provider.blank?
      return if Providers.registered?(provider)

      errors.add(:provider, :inclusion, message: "is not a registered provider")
    end
  end
end
