require "rails_helper"

RSpec.describe "ActiveBilling::Api::V1::Usages", type: :request do
  include_context "api enabled"

  let(:store) { create(:store) }
  let(:base) { "/active_billing/api/v1/usages" }
  let(:month) { Date.current.beginning_of_month }
  let(:usage_params) do
    { usage: { billable_entity_type: "Store", billable_entity_id: store.id, month: month } }
  end

  describe "POST /usages" do
    it "creates a usage" do
      post base, params: usage_params, headers: api_headers
      expect(response).to have_http_status(:created)
    end

    context "when one already exists for the cycle" do
      it "responds with conflict" do
        create(:active_billing_usage, billable_entity: store, month: month)

        post base, params: usage_params, headers: api_headers

        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe "POST /usages/:id/closure" do
    it "closes the usage" do
      usage = create(:active_billing_usage, billable_entity: store)
      post "#{base}/#{usage.id}/closure", headers: api_headers
      expect(json_body).to include("closed" => true)
    end
  end

  describe "DELETE /usages/:id" do
    context "when empty" do
      it "hard-deletes the usage" do
        usage = create(:active_billing_usage, billable_entity: store)
        expect do
          delete "#{base}/#{usage.id}", headers: api_headers
        end.to change(ActiveBilling::Usage, :count).by(-1)
      end
    end

    context "when it has events" do
      it "responds with conflict" do
        usage = create(:active_billing_usage, billable_entity: store)
        create(:active_billing_event, usage: usage)

        delete "#{base}/#{usage.id}", headers: api_headers
        expect(response).to have_http_status(:conflict)
      end
    end
  end
end
