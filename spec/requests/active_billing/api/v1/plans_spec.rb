require "rails_helper"

RSpec.describe "ActiveBilling::Api::V1::Plans", type: :request do
  include_context "api enabled"

  let(:base) { "/active_billing/api/v1/plans" }

  describe "GET /plans" do
    it "lists plans with money as integer cents" do
      plan = create(:active_billing_plan, price_in_cents: 9_900)

      get base, headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(json_body.first).to include("uuid" => plan.uuid, "price_in_cents" => 9_900)
    end
  end

  describe "GET /plans/:id" do
    it "shows one plan" do
      plan = create(:active_billing_plan)
      get "#{base}/#{plan.id}", headers: api_headers
      expect(json_body).to include("id" => plan.id)
    end
  end

  describe "POST /plans" do
    context "with valid params" do
      it "creates a plan" do
        expect do
          post base, params: { plan: { name: "Pro", price_in_cents: 9_900, interval: "monthly" } }, headers: api_headers
        end.to change(ActiveBilling::Plan, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context "with invalid params" do
      it "responds with unprocessable entity" do
        post base, params: { plan: { name: "" } }, headers: api_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /plans/:id" do
    it "updates a plan" do
      plan = create(:active_billing_plan, name: "Old")
      patch "#{base}/#{plan.id}", params: { plan: { name: "New" } }, headers: api_headers
      expect(json_body).to include("name" => "New")
    end
  end

  describe "DELETE /plans/:id" do
    context "when the plan was never used" do
      it "hard-deletes it" do
        plan = create(:active_billing_plan)
        expect do
          delete "#{base}/#{plan.id}", headers: api_headers
        end.to change(ActiveBilling::Plan, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when the plan has been used" do
      it "deactivates instead of deleting" do
        plan = create(:active_billing_plan)
        create(:active_billing_billing, plan: plan)

        expect do
          delete "#{base}/#{plan.id}", headers: api_headers
        end.not_to change(ActiveBilling::Plan, :count)

        expect(json_body).to include("active" => false)
      end
    end
  end
end
