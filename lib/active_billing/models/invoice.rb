module ActiveBilling
  class Invoice < ActiveRecord::Base
    include Concerns::TimestampStoreAccessor
    include Concerns::NfeDescription

    CANCEL_LIMIT_DAYS = 10

    attribute :add_usages_ids, :integer, array: true

    email_timestamp_store_accessors :notification, :charge

    attribute :amount_in_cents, :active_billing_money

    enum :state, {
      created: "created",
      processing: "processing",
      issued: "issued",
      cancelled: "cancelled",
      failed: "failed"
    }

    enum :payment_collected_medium, {
      missing: "missing",
      transfer: "transfer",
      charge: "charge",
      gateway: "gateway"
    }, default: "missing", suffix: "payment"

    belongs_to :resource, polymorphic: true
    belongs_to :billing, class_name: "ActiveBilling::Billing", optional: true

    has_many :charges, class_name: "ActiveBilling::Charge",
                       foreign_key: "invoice_id",
                       inverse_of: :invoice,
                       dependent: :nullify

    has_many :items, class_name: "ActiveBilling::InvoiceItem",
                     foreign_key: "billing_invoice_id",
                     inverse_of: :invoice,
                     dependent: :destroy
    accepts_nested_attributes_for :items, allow_destroy: true

    has_many :usages, -> { distinct }, through: :items

    validates :state, exclusion: { in: %w[cancelled] }, unless: :cancellable?
    validates :amount_in_cents, comparison: { greater_than: 0 }
    validates :description, presence: true
    validate :usages_belong_to_same_entity

    before_validation :set_issued_at
    before_validation :remove_items_from_removed_usages
    before_validation :add_items_from_added_usages
    before_validation :set_amount
    before_validation :set_description

    scope :for_billable_entity, ->(type, id) {
      joins(:billing).where(active_billing_billings: { billable_entity_type: type, billable_entity_id: id })
    }

    def cancellable?
      issued_at.present? &&
        Date.current.before?(issued_at.next_month.change(day: CANCEL_LIMIT_DAYS))
    end

    def issuable?
      created? || failed?
    end

    def add_usages_ids
      return self[:add_usages_ids] if self[:add_usages_ids].present?

      self[:add_usages_ids] = usage_ids
      self[:add_usages_ids]
    end

    def add_usages_ids=(ids)
      super(ids)
      super(add_usages_ids.compact)
    end

    def add_usages
      ActiveBilling::Usage.where(id: add_usages_ids)
    end

    private

    def set_description
      return if description.present?

      uuid_month = if add_usages_ids.any?
                     add_usages.pluck(:uuid, :month)
                   elsif usages.any?
                     usages.pluck(:uuid, :month)
                   end
      return if uuid_month.blank?

      month = uuid_month.first[1]
      usage_uuids = uuid_month.map { |i| i[0] }.join(", #")
      self.description = format(
        nfe_resource_description,
        { month: I18n.l(month, format: :month), uuids: usage_uuids }
      )
    end

    def set_issued_at
      return unless state_changed?(to: "issued")
      return if issued_at.present?

      self.issued_at = Date.current
    end

    def remove_items_from_removed_usages
      to_remove = usage_ids.difference(add_usages_ids)

      return if to_remove.empty?
      return errors.add(:items, :invalid, message: "cannot be changed after invoice is issued") unless issuable?

      items.where(usage_id: to_remove).destroy_all
    end

    def add_items_from_added_usages
      to_add = add_usages_ids.difference(usage_ids)
      return if to_add.blank?
      return errors.add(:items, :invalid, message: "cannot change items after is issued") unless issuable?

      items_from_usages = ActiveBilling::Usage.where(id: to_add).map(&:to_invoice_items_attributes).flatten
      if items_from_usages.blank?
        return errors.add(:items, :blank, message: "items cannot be blank when usages are informed")
      end

      self.items_attributes = items_from_usages
    end

    def set_amount
      return if items.empty?
      return unless issuable?

      self.amount_in_cents = ActiveBilling::Money.from_amount(items.sum(&:price))
    end

    def usages_belong_to_same_entity
      return true if add_usages_ids.empty?

      # Override this method in your application to validate that
      # all usages belong to the same billing entity
      true
    end
  end
end
