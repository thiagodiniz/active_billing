module ActiveBilling
  class Usage < ActiveRecord::Base
    include Concerns::TimestampStoreAccessor

    email_timestamp_store_accessors :notification, :charge

    attribute :total_cost_in_cents, :active_billing_money

    belongs_to :billable_entity, polymorphic: true
    belongs_to :billing, class_name: "ActiveBilling::Billing", optional: true

    has_many :events, foreign_key: "billing_usage_id",
                      class_name: "ActiveBilling::Event",
                      inverse_of: :usage,
                      dependent: :destroy

    has_many :invoice_items, class_name: "ActiveBilling::InvoiceItem",
                             foreign_key: "usage_id",
                             dependent: :nullify,
                             inverse_of: :usage
    has_many :invoices, -> { distinct }, through: :invoice_items

    scope :for_billable_entity, ->(type, id) { where(billable_entity_type: type, billable_entity_id: id) }
    scope :for_month, ->(date) { where(month: date.beginning_of_month) }
    scope :for_year, ->(year) { where("extract(year from month) = ?", year) }

    scope :with_invoices, -> {
      where(id: ActiveBilling::Usage.joins(:invoice_items)
                                    .where.not(billing_invoice_items: { billing_invoice_id: nil })
                                    .select(:id))
    }

    scope :without_invoices, -> {
      where.not(id: ActiveBilling::Usage.joins(:invoice_items)
                                        .where.not(billing_invoice_items: { billing_invoice_id: nil })
                                        .select(:id))
    }

    scope :invoice_presence, ->(presence) {
      case presence
      when "with"
        with_invoices
      when "without"
        without_invoices
      else
        all
      end
    }

    scope :with_invoice_state, ->(state) {
      where(id: ActiveBilling::Usage.joins(:invoice_items)
                                    .joins("JOIN active_billing_invoices ON active_billing_invoices.id = active_billing_invoice_items.billing_invoice_id")
                                    .where(active_billing_invoices: { state: state })
                                    .select(:id))
    }

    def self.current_month
      find_by(month: Date.current.beginning_of_month)
    end

    def small_description
      "#{id} - #{I18n.l(month, format: :month)}"
    end

    def issued_invoice
      invoices.issued.first
    end

    def has_invoice?
      invoices.exists?
    end

    def invoice_status
      return I18n.t("active_billing.usage.no_invoice", default: "No invoice") unless has_invoice?

      latest_invoice = invoices.order(:created_at).last
      I18n.t("active_billing.invoice.states.#{latest_invoice.state}", default: latest_invoice.state.humanize)
    end

    def calculate_total_cost
      # Override this method in your application to calculate the total cost
      # based on your pricing model and events
      events.sum { |event| calculate_event_cost(event) }
    end

    def calculate_event_cost(_event)
      # Override this method in your application to calculate the cost
      # for each event type
      0.0
    end

    def to_invoice_items_attributes
      events_grouped = events.chargeable.group(:kind).count

      events_grouped.map do |kind, quantity|
        {
          key: kind,
          quantity: quantity,
          unit_price: event_price_for(kind),
          usage_id: id
        }
      end
    end

    def event_price_for(_kind)
      # Override this method in your application to return the price
      # for each event type
      0.0
    end

    def self.ransackable_scopes(_auth_object = nil)
      %i[with_invoices without_invoices invoice_presence with_invoice_state for_month for_year]
    end
  end
end
