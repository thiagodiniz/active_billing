require "rails_helper"

RSpec.describe "ActiveBilling::Api::V1::Invoices", type: :request do
  include_context "api enabled"

  let(:store) { create(:store) }
  let(:billing) { create(:active_billing_billing, billable_entity: store) }
  let(:base) { "/active_billing/api/v1/invoices" }

  describe "POST /invoices" do
    it "creates an invoice with amount as integer cents" do
      post base,
           params: { invoice: { billing_id: billing.id, resource_type: "Store", resource_id: store.id,
                                description: "May usage", amount_in_cents: 5_000 } },
           headers: api_headers

      expect(response).to have_http_status(:created)
      expect(json_body).to include("amount_in_cents" => 5_000, "state" => "created")
    end
  end

  describe "POST /invoices/:id/issuance" do
    context "when issuable" do
      it "issues the invoice" do
        invoice = create(:active_billing_invoice, billing: billing)
        post "#{base}/#{invoice.id}/issuance", headers: api_headers
        expect(json_body).to include("state" => "issued")
      end
    end

    context "when already issued" do
      it "responds with conflict" do
        invoice = create(:active_billing_invoice, :issued, billing: billing)
        post "#{base}/#{invoice.id}/issuance", headers: api_headers
        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe "POST /invoices/:id/cancellation" do
    context "when cancellable" do
      it "cancels the invoice" do
        invoice = create(:active_billing_invoice, :issued, billing: billing)
        post "#{base}/#{invoice.id}/cancellation", headers: api_headers
        expect(json_body).to include("state" => "cancelled")
      end
    end

    context "when not cancellable" do
      it "responds with conflict" do
        invoice = create(:active_billing_invoice, billing: billing)
        post "#{base}/#{invoice.id}/cancellation", headers: api_headers
        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe "DELETE /invoices/:id" do
    it "soft-deletes the invoice" do
      invoice = create(:active_billing_invoice, billing: billing)
      expect do
        delete "#{base}/#{invoice.id}", headers: api_headers
      end.not_to change(ActiveBilling::Invoice, :count)
      expect(invoice.reload).to be_discarded
    end
  end

  describe "nested items" do
    let(:invoice) { create(:active_billing_invoice, billing: billing) }

    it "creates an item under an issuable invoice" do
      post "#{base}/#{invoice.id}/items",
           params: { item: { key: "api_calls", quantity: 10, unit_price: 1.5 } },
           headers: api_headers
      expect(response).to have_http_status(:created)
    end

    context "when the invoice is issued" do
      it "rejects item writes with conflict" do
        issued = create(:active_billing_invoice, :issued, billing: billing)
        post "#{base}/#{issued.id}/items",
             params: { item: { key: "api_calls", quantity: 10, unit_price: 1.5 } },
             headers: api_headers
        expect(response).to have_http_status(:conflict)
      end
    end
  end
end
