require "rails_helper"

RSpec.describe "ActiveBilling::Invoices", type: :request do
  let(:store) { create(:store) }
  let(:other_store) { create(:store) }
  let(:billing) { create(:active_billing_billing, billable_entity: store) }
  let(:invoice) { create(:active_billing_invoice, billing: billing) }
  let(:other_invoice) do
    create(:active_billing_invoice, billing: create(:active_billing_billing, billable_entity: other_store))
  end

  describe "GET /active_billing/invoices" do
    context "without a resolved entity" do
      it "responds with bad request" do
        get "/active_billing/invoices"
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "without config.portal_billable_entity" do
      it "responds with forbidden" do
        ActiveBilling.configuration.portal_billable_entity = nil
        get "/active_billing/invoices", headers: as_entity(store)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with a resolved entity" do
      it "responds successfully" do
        get "/active_billing/invoices", headers: as_entity(store)
        expect(response).to have_http_status(:ok)
      end

      it "lists only invoices for the entity" do
        invoice
        other_invoice

        get "/active_billing/invoices", headers: as_entity(store)

        expect(response.body).to include(invoice.uuid)
        expect(response.body).not_to include(other_invoice.uuid)
      end

      it "renders the navigation without entity params" do
        get "/active_billing/invoices", headers: as_entity(store)

        expect(response.body).to include(%(href="/active_billing/usages"))
        expect(response.body).not_to include("billable_entity_id=")
      end

      it "ignores billable_entity_id from the query string" do
        other_invoice
        get "/active_billing/invoices",
            params: { billable_entity_id: other_store.id, billable_entity_type: "Store" },
            headers: as_entity(store)
        expect(response.body).not_to include(other_invoice.uuid)
      end
    end
  end

  describe "GET /active_billing/invoices/:id" do
    it "responds successfully" do
      get "/active_billing/invoices/#{invoice.id}", headers: as_entity(store)
      expect(response).to have_http_status(:ok)
    end

    context "without a resolved entity" do
      it "responds with bad request" do
        get "/active_billing/invoices/#{invoice.id}"
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the invoice belongs to another entity" do
      it "responds with not found" do
        get "/active_billing/invoices/#{other_invoice.id}", headers: as_entity(store)
        expect(response).to have_http_status(:not_found)
      end

      it "ignores billable_entity_id from the query string" do
        get "/active_billing/invoices/#{other_invoice.id}",
            params: { billable_entity_id: other_store.id, billable_entity_type: "Store" },
            headers: as_entity(store)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when requesting a PDF" do
      before { ActiveBilling.configuration.company = { name: "Example, LLC", email: "billing@example.com" } }

      it "responds with a PDF document" do
        get "/active_billing/invoices/#{invoice.id}.pdf", headers: as_entity(store)

        expect(response.media_type).to eq("application/pdf")
        expect(response.body).to start_with("%PDF")
      end

      context "when the invoice belongs to another entity" do
        it "responds with not found" do
          get "/active_billing/invoices/#{other_invoice.id}.pdf", headers: as_entity(store)
          expect(response).to have_http_status(:not_found)
        end
      end

      context "without a resolved entity" do
        it "responds with bad request" do
          get "/active_billing/invoices/#{invoice.id}.pdf"
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end
end
