require "rails_helper"

RSpec.describe "ActiveBilling::Plans", type: :request do
  let(:store) { create(:store) }
  let(:scope) { { billable_entity_id: store.id, billable_entity_type: "Store" } }

  describe "GET /active_billing/plan" do
    context "when the entity has a current billing with a plan" do
      it "shows the current plan name" do
        plan = create(:active_billing_plan, name: "Growth")
        create(:active_billing_billing, billable_entity: store, plan: plan)

        get "/active_billing/plan", params: scope

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Growth")
      end
    end

    context "when the entity has no billing" do
      it "renders the no-billing message" do
        get "/active_billing/plan", params: scope
        expect(response.body).to include(I18n.t("active_billing.plan.no_billing"))
      end
    end

    context "without a billable_entity_id" do
      it "responds with bad request" do
        get "/active_billing/plan"
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
