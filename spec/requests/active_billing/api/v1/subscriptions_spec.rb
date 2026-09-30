require "rails_helper"

RSpec.describe "ActiveBilling::Api::V1::Subscriptions", type: :request do
  include_context "api enabled"

  let(:store) { create(:store) }
  let(:plan) { create(:active_billing_plan) }
  let(:base) { "/active_billing/api/v1/subscriptions" }

  describe "GET /subscriptions" do
    it "lists kept subscriptions scoped by billable entity" do
      mine = create(:active_billing_subscription, billable_entity: store)
      other = create(:active_billing_subscription, billable_entity: create(:store))

      get base, params: { billable_entity_type: "Store", billable_entity_id: store.id }, headers: api_headers

      uuids = json_body.map { |b| b["uuid"] }
      expect(uuids).to include(mine.uuid)
      expect(uuids).not_to include(other.uuid)
    end
  end

  describe "POST /subscriptions" do
    it "creates a subscription and snapshots the plan" do
      post base,
           params: { subscription: { billable_entity_type: "Store", billable_entity_id: store.id, plan_id: plan.id } },
           headers: api_headers

      expect(response).to have_http_status(:created)
      expect(json_body).to include("plan_name" => plan.name)
    end
  end

  describe "PUT /subscriptions/:id/plan" do
    it "associates a new plan while open" do
      subscription = create(:active_billing_subscription, :without_plan, billable_entity: store)
      new_plan = create(:active_billing_plan, name: "Enterprise")

      put "#{base}/#{subscription.id}/plan", params: { plan_id: new_plan.id }, headers: api_headers

      expect(json_body).to include("plan_name" => "Enterprise")
    end
  end

  describe "POST /subscriptions/:id/finalization" do
    context "when open" do
      it "finalizes the subscription" do
        subscription = create(:active_billing_subscription, billable_entity: store)
        post "#{base}/#{subscription.id}/finalization", headers: api_headers
        expect(json_body).to include("state" => "finalized")
      end
    end

    context "when already finalized" do
      it "responds with conflict" do
        subscription = create(:active_billing_subscription, :finalized, billable_entity: store)
        post "#{base}/#{subscription.id}/finalization", headers: api_headers
        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe "DELETE /subscriptions/:id" do
    it "soft-deletes the subscription" do
      subscription = create(:active_billing_subscription, billable_entity: store)

      expect do
        delete "#{base}/#{subscription.id}", headers: api_headers
      end.not_to change(ActiveBilling::Subscription, :count)

      expect(response).to have_http_status(:no_content)
      expect(subscription.reload).to be_discarded
    end
  end
end
