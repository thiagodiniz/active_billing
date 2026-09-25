require "receipts"

module ActiveBilling
  # Renders an Invoice as a PDF through the `receipts` gem.
  #
  # Issuer data comes from `config.company`; the recipient block comes from
  # `config.invoice_recipient` when set, otherwise from the billable entity
  # (`name`, `address`, `email`, `tax_id` when it responds to them).
  class InvoicePdf
    RECIPIENT_ATTRIBUTES = %i[name address email tax_id].freeze

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
      [
        [t("number"), invoice.uuid],
        [t("issued_at"), issued_on],
        [t("state"), state_label],
        [t("period"), period],
        [t("nfe_number"), invoice.nfe_number]
      ].select { |_label, value| value.present? }.map { |label, value| [label, escape(value)] }
    end

    def company
      company = config.company
      return { email: nil }.merge(company) if company.present? && company[:name].present?

      raise ActiveBilling::Error, "config.company must be set with at least :name to render invoice PDFs"
    end

    def recipient
      recipient_lines.filter_map { |line| escape(line) }
    end

    def line_items
      [header_row, *item_rows, total_row]
    end

    def footer
      config.invoice_pdf_footer.presence || I18n.t("active_billing.invoice.pdf.footer", default: "")
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

    def recipient_lines
      custom = config.invoice_recipient
      return Array(custom.call(invoice)) if custom.respond_to?(:call)

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
      return rows if rows.any?

      [[escape(invoice.description), nil, nil, format_cents(invoice.amount_in_cents)]]
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
      "<b>#{escape(text)}</b>"
    end

    # Prawn parses inline markup (<b>, <link>, ...) in table cells.
    def escape(text)
      return if text.nil?

      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end

    def t(key)
      I18n.t("active_billing.invoice.pdf.#{key}", default: nil) ||
        I18n.t("active_billing.invoice.pdf.#{key}", locale: :en)
    end
  end
end
