module ActiveBilling
  class Event < ActiveRecord::Base
    belongs_to :resource, polymorphic: true, optional: true
    belongs_to :usage, class_name: "ActiveBilling::Usage",
                       foreign_key: "billing_usage_id",
                       inverse_of: :events

    enum :kind, {
      subscription_active: "subscription_active",
      charge_paid: "charge_paid",
      charge_cancelled: "charge_cancelled",
      sms_sent: "sms_sent",
      email_sent: "email_sent",
      api_call: "api_call",
      storage_used: "storage_used",
      custom_event: "custom_event"
    }

    validates :kind, presence: true
    validate :correct_resource_class

    before_create :set_chargeable

    scope :chargeable, -> { where(chargeable: true) }

    def extra_charges_count
      [(metadata["issued_charges_count"] || 0) - 1, 0].max
    end

    private

    def set_chargeable
      self.chargeable = true
      # Override this method in your application for custom chargeable logic
    end

    def correct_resource_class
      return if resource_type.blank?

      # Override this method in your application to validate resource types
      # based on event kind
      true
    end
  end
end
