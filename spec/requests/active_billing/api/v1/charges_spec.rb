require "rails_helper"

RSpec.describe "ActiveBilling::Api::V1::Charges", type: :request do
  include_context "api enabled"

  let(:store) { create(:store) }
  let(:base) { "/active_billing/api/v1/charges" }

  describe "POST /charges" do
    it "creates a charge" do
      invoice = create(:active_billing_invoice)
      post base,
           params: { charge: { invoice_id: invoice.id, resource_type: "Store", resource_id: store.id } },
           headers: api_headers
      expect(response).to have_http_status(:created)
    end
  end

  describe "DELETE /charges/:id" do
    it "soft-deletes the charge" do
      charge = create(:active_billing_charge, resource: store)
      expect do
        delete "#{base}/#{charge.id}", headers: api_headers
      end.not_to change(ActiveBilling::Charge, :count)
      expect(charge.reload).to be_discarded
    end
  end

  describe "POST /charges/:id/payment" do
    it "reports not implemented until the state machine ships" do
      charge = create(:active_billing_charge, resource: store)
      post "#{base}/#{charge.id}/payment", headers: api_headers
      expect(response).to have_http_status(:not_implemented)
    end
  end
end
