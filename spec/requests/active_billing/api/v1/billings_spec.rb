require "rails_helper"

RSpec.describe "ActiveBilling::Api::V1::Billings", type: :request do
  include_context "api enabled"

  let(:store) { create(:store) }
  let(:plan) { create(:active_billing_plan) }
  let(:base) { "/active_billing/api/v1/billings" }

  describe "GET /billings" do
    it "lists kept billings scoped by billable entity" do
      mine = create(:active_billing_billing, billable_entity: store)
      other = create(:active_billing_billing, billable_entity: create(:store))

      get base, params: { billable_entity_type: "Store", billable_entity_id: store.id }, headers: api_headers

      uuids = json_body.map { |b| b["uuid"] }
      expect(uuids).to include(mine.uuid)
      expect(uuids).not_to include(other.uuid)
    end
  end

  describe "POST /billings" do
    it "creates a billing and snapshots the plan" do
      post base,
           params: { billing: { billable_entity_type: "Store", billable_entity_id: store.id, plan_id: plan.id } },
           headers: api_headers

      expect(response).to have_http_status(:created)
      expect(json_body).to include("plan_name" => plan.name)
    end
  end

  describe "PUT /billings/:id/plan" do
    it "associates a new plan while open" do
      billing = create(:active_billing_billing, :without_plan, billable_entity: store)
      new_plan = create(:active_billing_plan, name: "Enterprise")

      put "#{base}/#{billing.id}/plan", params: { plan_id: new_plan.id }, headers: api_headers

      expect(json_body).to include("plan_name" => "Enterprise")
    end
  end

  describe "POST /billings/:id/finalization" do
    context "when open" do
      it "finalizes the billing" do
        billing = create(:active_billing_billing, billable_entity: store)
        post "#{base}/#{billing.id}/finalization", headers: api_headers
        expect(json_body).to include("state" => "finalized")
      end
    end

    context "when already finalized" do
      it "responds with conflict" do
        billing = create(:active_billing_billing, :finalized, billable_entity: store)
        post "#{base}/#{billing.id}/finalization", headers: api_headers
        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe "DELETE /billings/:id" do
    it "soft-deletes the billing" do
      billing = create(:active_billing_billing, billable_entity: store)

      expect do
        delete "#{base}/#{billing.id}", headers: api_headers
      end.not_to change(ActiveBilling::Billing, :count)

      expect(response).to have_http_status(:no_content)
      expect(billing.reload).to be_discarded
    end
  end
end
