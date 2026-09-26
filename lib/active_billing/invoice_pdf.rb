require "receipts"

module ActiveBilling
  # Renders an Invoice as a PDF through the `receipts` gem.
  #
  # Issuer data comes from `config.company`; the recipient block comes from
  # `config.invoice_recipient` when set, otherwise from the billable entity
  # (`name`, `address`, `email`, `tax_id` when it responds to them).
  class InvoicePdf
    RECIPIENT_ATTRIBUTES = %i[name address email tax_id].freeze

    LABEL_DEFAULTS = {
      number: "Invoice number", issued_at: "Issued on", not_issued: "Not issued yet", state: "Status",
      period: "Billing period", nfe_number: "NF-e number", item: "Item", unit_price: "Unit price",
      quantity: "Quantity", amount: "Amount", total: "Total", footer: "Thank you for your business."
    }.freeze

    attr_reader :invoice

    def initialize(invoice)
      @invoice = invoice
    end

    def render
      document.render
    end

    def render_file(path)
      document.render_file(path)
    end

    def document
      Receipts::Invoice.new(
        details: details,
        company: company,
        recipient: recipient,
        line_items: line_items,
        footer: footer,
        page_size: config.invoice_pdf_page_size
      )
    end

    def details
      rows = { number: invoice.uuid, issued_at: issued_on, state: state_label, period: period,
               nfe_number: invoice.nfe_number }
      rows.filter_map { |key, value| [t(key), escape(value)] if value.present? }
    end

    def company
      company = config.company
      return company if company.present? && company[:name].present?

      raise ActiveBilling::Error, "config.company must be set with at least :name to render invoice PDFs"
    end

    def recipient
      (custom_recipient || entity_recipient).filter_map { |value| escape(value) }
    end

    def line_items
      [header_row, *item_rows, total_row]
    end

    def footer
      config.invoice_pdf_footer.presence || t("footer")
    end

    private

    def config
      ActiveBilling.configuration
    end

    def issued_on
      invoice.issued_at.present? ? I18n.l(invoice.issued_at) : t("not_issued")
    end

    def state_label
      I18n.t("active_billing.invoice.states.#{invoice.state}", default: invoice.state.humanize)
    end

    def period
      start = invoice.billing&.period_start
      return if start.nil?

      finish = invoice.billing.period_end
      [I18n.l(start), finish && I18n.l(finish)].compact.join(" - ")
    end

    def custom_recipient
      Array(config.invoice_recipient.call(invoice)) if config.invoice_recipient.respond_to?(:call)
    end

    def entity_recipient
      entity = invoice.billing&.billable_entity || invoice.resource
      return [] if entity.nil?

      RECIPIENT_ATTRIBUTES.map { |attribute| entity_value(entity, attribute) }
    end

    def entity_value(entity, attribute)
      entity.public_send(attribute).presence if entity.respond_to?(attribute)
    end

    def header_row
      [bold(t("item")), bold(t("unit_price")), bold(t("quantity")), bold(t("amount"))]
    end

    def item_rows
      rows = invoice.items.map { |item| item_row(item) }
      rows.presence || [[escape(invoice.description), nil, nil, format_cents(invoice.amount_in_cents)]]
    end

    def item_row(item)
      [escape(item.description.presence || item.key), money(item.unit_price), item.quantity.to_s, money(item.price)]
    end

    def total_row
      [nil, nil, bold(t("total")), bold(format_cents(invoice.amount_in_cents))]
    end

    def money(amount)
      ActiveBilling::Money.from_amount(amount.to_d).to_s
    end

    def format_cents(value)
      value.is_a?(ActiveBilling::Money) ? value.to_s : ActiveBilling::Money.from_cents(value.to_i).to_s
    end

    def bold(text)
      "<b>#{text}</b>"
    end

    # Receipts renders cells with Prawn inline_format, so free text must not be parsed as markup.
    def escape(value)
      ERB::Util.html_escape(value.to_s) unless value.nil?
    end

    def t(key)
      I18n.t("active_billing.invoice.pdf.#{key}", default: LABEL_DEFAULTS.fetch(key.to_sym))
    end
  end
end
