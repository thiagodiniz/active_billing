require "rails_helper"

RSpec.describe ActiveBilling::InvoicePdf do
  subject(:pdf) { described_class.new(invoice) }

  let(:store) { create(:store, name: "Acme Store") }
  let(:billing) do
    create(:active_billing_billing, billable_entity: store,
                                    period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31))
  end
  let(:invoice) { create(:active_billing_invoice, :issued, billing: billing, amount_in_cents: 1_500) }
  let(:company) { { name: "Example, LLC", address: "123 Fake Street", email: "billing@example.com" } }

  around do |example|
    original = ActiveBilling.configuration.dup
    ActiveBilling.configuration.company = company
    example.run
  ensure
    ActiveBilling.configuration = original
  end

  describe "#render" do
    it "returns a PDF document" do
      expect(pdf.render).to start_with("%PDF")
    end

    context "with a company without email" do
      let(:company) { { name: "Example, LLC" } }

      it "returns a PDF document" do
        expect(pdf.render).to start_with("%PDF")
      end
    end

    context "without company configured" do
      let(:company) { nil }

      it "raises an error" do
        expect { pdf.render }.to raise_error(ActiveBilling::Error)
      end
    end
  end

  describe "#details" do
    it "includes the invoice number" do
      expect(pdf.details).to include(["Invoice number", invoice.uuid])
    end

    it "includes the billing period" do
      expect(pdf.details).to include(["Billing period", "2026-01-01 - 2026-01-31"])
    end
  end

  describe "#recipient" do
    it "uses the billable entity name by default" do
      expect(pdf.recipient).to eq(["Acme Store"])
    end

    context "with a custom recipient" do
      before { ActiveBilling.configuration.invoice_recipient = ->(inv) { ["Custom", inv.uuid] } }

      it "calls the configured lambda" do
        expect(pdf.recipient).to eq(["Custom", invoice.uuid])
      end
    end

    context "with markup in the entity name" do
      let(:store) { create(:store, name: "<link href='http://evil'>Acme</link>") }

      it "escapes the value" do
        expect(pdf.recipient).to eq(["&lt;link href=&#39;http://evil&#39;&gt;Acme&lt;/link&gt;"])
      end
    end

    context "with markup in a custom recipient" do
      before { ActiveBilling.configuration.invoice_recipient = ->(_inv) { ["<b>Custom</b>"] } }

      it "escapes the value" do
        expect(pdf.recipient).to eq(["&lt;b&gt;Custom&lt;/b&gt;"])
      end
    end
  end

  describe "#line_items" do
    context "with items" do
      before { create(:active_billing_invoice_item, invoice: invoice, key: "api_calls", quantity: 10, unit_price: 1.5) }

      it "renders one row per item" do
        expect(pdf.line_items[1]).to eq(["api_calls", "BRL 1.50", "10", "BRL 15.00"])
      end

      it "ends with the total" do
        expect(pdf.line_items.last).to eq([nil, nil, "<b>Total</b>", "<b>BRL 15.00</b>"])
      end
    end

    context "with markup in the item key" do
      before { create(:active_billing_invoice_item, invoice: invoice, key: "<b>bold</b>", quantity: 1, unit_price: 1) }

      it "escapes the value" do
        expect(pdf.line_items[1].first).to eq("&lt;b&gt;bold&lt;/b&gt;")
      end
    end

    context "without items" do
      it "falls back to the invoice description" do
        expect(pdf.line_items[1]).to eq(["Test invoice", nil, nil, "BRL 15.00"])
      end

      context "with markup in the invoice description" do
        let(:invoice) do
          create(:active_billing_invoice, :issued, billing: billing, amount_in_cents: 1_500, description: "A <b>B</b>")
        end

        it "escapes the value" do
          expect(pdf.line_items[1].first).to eq("A &lt;b&gt;B&lt;/b&gt;")
        end
      end
    end

    context "with an untranslated locale" do
      around do |example|
        I18n.enforce_available_locales = false
        I18n.with_locale(:"pt-BR") { example.run }
      ensure
        I18n.enforce_available_locales = true
      end

      it "falls back to English labels" do
        expect(pdf.line_items.last[2]).to eq("<b>Total</b>")
      end
    end
  end
end
