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
    validates :amount_in_cents, comparison: { greater_than_or_equal_to: 0 }
    validates :description, presence: true
    validate :items_must_be_editable
    validate :usages_belong_to_same_entity

    before_validation :set_issued_at
    before_validation :sync_items_with_usages
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
      self[:add_usages_ids] ||= usage_ids
    end

    def add_usages_ids=(ids)
      super(Array(ids).compact)
    end

    def add_usages
      ActiveBilling::Usage.where(id: add_usages_ids)
    end

    def to_pdf
      ActiveBilling::InvoicePdf.new(self).render
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
        { month: I18n.l(month, format: month_format), uuids: usage_uuids }
      )
    end

    def month_format
      I18n.t("active_billing.invoice.month_format", default: "%B %Y")
    end

    def set_issued_at
      return unless state_changed?(to: "issued")
      return if issued_at.present?

      self.issued_at = Date.current
    end

    # Reconciles line items with `add_usages_ids` in memory only: removed items are
    # marked for destruction and new ones are built, so nothing is written until the
    # record is saved and everything happens inside the save transaction.
    def sync_items_with_usages
      return unless items_changed?
      return unless issuable?

      obsolete_items.each(&:mark_for_destruction)
      build_items_for(pending_usage_ids)
    end

    def items_changed?
      pending_usage_ids.any? || obsolete_items.any?
    end

    def live_items
      items.reject(&:marked_for_destruction?)
    end

    def pending_usage_ids
      add_usages_ids - live_items.filter_map(&:usage_id)
    end

    def obsolete_items
      live_items.select { |item| item.usage_id.present? && add_usages_ids.exclude?(item.usage_id) }
    end

    def build_items_for(usage_ids_to_add)
      return if usage_ids_to_add.empty?

      attributes = ActiveBilling::Usage.where(id: usage_ids_to_add).flat_map(&:to_invoice_items_attributes)
      return errors.add(:items, :blank, message: "cannot be blank when usages are informed") if attributes.empty?

      attributes.each { |item_attributes| items.build(item_attributes) }
    end

    def set_amount
      return unless issuable?
      return if live_items.empty?

      self.amount_in_cents = ActiveBilling::Money.from_amount(live_items.sum(&:price))
    end

    def items_must_be_editable
      return if issuable?
      return unless items_changed?

      errors.add(:items, :invalid, message: "cannot be changed after the invoice is issued")
    end

    def usages_belong_to_same_entity
      return true if add_usages_ids.empty?

      # Override this method in your application to validate that
      # all usages belong to the same billing entity
      true
    end
  end
end
