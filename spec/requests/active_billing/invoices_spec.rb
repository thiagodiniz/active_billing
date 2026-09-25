require "rails_helper"

RSpec.describe "ActiveBilling::Invoices", type: :request do
  let(:store) { create(:store) }
  let(:billing) { create(:active_billing_billing, billable_entity: store) }

  describe "GET /active_billing/invoices" do
    context "without a billable_entity_id" do
      it "responds with bad request" do
        get "/active_billing/invoices"
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with a billable_entity_id" do
      it "responds successfully" do
        get "/active_billing/invoices", params: { billable_entity_id: store.id, billable_entity_type: "Store" }
        expect(response).to have_http_status(:ok)
      end

      it "lists only invoices for the entity" do
        mine = create(:active_billing_invoice, billing: billing)
        other = create(:active_billing_invoice,
                       billing: create(:active_billing_billing, billable_entity: create(:store)))

        get "/active_billing/invoices", params: { billable_entity_id: store.id, billable_entity_type: "Store" }

        expect(response.body).to include(mine.uuid)
        expect(response.body).not_to include(other.uuid)
      end
    end
  end

  describe "GET /active_billing/invoices/:id" do
    let(:invoice) { create(:active_billing_invoice, billing: billing) }

    it "responds successfully" do
      get "/active_billing/invoices/#{invoice.id}",
          params: { billable_entity_id: store.id, billable_entity_type: "Store" }
      expect(response).to have_http_status(:ok)
    end

    context "when requesting a PDF" do
      around do |example|
        original = ActiveBilling.configuration.dup
        ActiveBilling.configuration.company = { name: "Example, LLC", email: "billing@example.com" }
        example.run
      ensure
        ActiveBilling.configuration = original
      end

      it "responds with a PDF document" do
        get "/active_billing/invoices/#{invoice.id}.pdf",
            params: { billable_entity_id: store.id, billable_entity_type: "Store" }

        expect(response.media_type).to eq("application/pdf")
        expect(response.body).to start_with("%PDF")
      end
    end
  end
end
