require "rails_helper"

RSpec.describe "ActiveBilling portal lists", type: :request do
  let(:store) { create(:store) }
  let(:billing) { create(:active_billing_billing, billable_entity: store) }

  describe "GET /active_billing/usages" do
    context "without a resolved entity" do
      it "responds with bad request" do
        get "/active_billing/usages"
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with a resolved entity" do
      it "responds successfully" do
        create(:active_billing_usage, billable_entity: store)
        get "/active_billing/usages", headers: as_entity(store)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /active_billing/charges" do
    context "with a resolved entity" do
      it "responds successfully" do
        create(:active_billing_charge, invoice: create(:active_billing_invoice, billing: billing))
        get "/active_billing/charges", headers: as_entity(store)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
