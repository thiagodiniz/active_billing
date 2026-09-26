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
    let(:other_invoice) do
      create(:active_billing_invoice, billing: create(:active_billing_billing, billable_entity: create(:store)))
    end

    it "responds successfully" do
      get "/active_billing/invoices/#{invoice.id}",
          params: { billable_entity_id: store.id, billable_entity_type: "Store" }
      expect(response).to have_http_status(:ok)
    end

    context "without a billable_entity_id" do
      it "responds with bad request" do
        get "/active_billing/invoices/#{invoice.id}"
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the invoice belongs to another entity" do
      it "responds with not found" do
        get "/active_billing/invoices/#{other_invoice.id}",
            params: { billable_entity_id: store.id, billable_entity_type: "Store" }
        expect(response).to have_http_status(:not_found)
      end
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

      context "when the invoice belongs to another entity" do
        it "responds with not found" do
          get "/active_billing/invoices/#{other_invoice.id}.pdf",
              params: { billable_entity_id: store.id, billable_entity_type: "Store" }
          expect(response).to have_http_status(:not_found)
        end
      end

      context "without a billable_entity_id" do
        it "responds with bad request" do
          get "/active_billing/invoices/#{invoice.id}.pdf"
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end

  describe "with config.portal_billable_entity" do
    let(:other_store) { create(:store) }
    let(:other_invoice) do
      create(:active_billing_invoice, billing: create(:active_billing_billing, billable_entity: other_store))
    end
    let(:invoice) { create(:active_billing_invoice, billing: billing) }

    around do |example|
      original = ActiveBilling.configuration.dup
      ActiveBilling.configuration.portal_billable_entity = ->(controller) { Store.find_by(id: controller.params[:me]) }
      example.run
    ensure
      ActiveBilling.configuration = original
    end

    it "scopes the index to the resolved entity" do
      invoice
      other_invoice
      get "/active_billing/invoices", params: { me: store.id }

      expect(response.body).to include(invoice.uuid)
      expect(response.body).not_to include(other_invoice.uuid)
    end

    it "renders the navigation without scope params" do
      get "/active_billing/invoices", params: { me: store.id }

      expect(response.body).to include(%(href="/active_billing/usages"))
      expect(response.body).not_to include("billable_entity_id=")
    end

    it "ignores billable_entity_id from the query string" do
      get "/active_billing/invoices/#{other_invoice.id}",
          params: { me: store.id, billable_entity_id: other_store.id, billable_entity_type: "Store" }
      expect(response).to have_http_status(:not_found)
    end

    it "shows the resolved entity's invoice" do
      get "/active_billing/invoices/#{invoice.id}", params: { me: store.id }
      expect(response).to have_http_status(:ok)
    end

    context "when no entity is resolved" do
      it "responds with bad request" do
        get "/active_billing/invoices", params: { billable_entity_id: store.id, billable_entity_type: "Store" }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
