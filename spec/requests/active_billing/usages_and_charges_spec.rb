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

  describe "GET /active_billing/usages/:id" do
    let(:usage) { create(:active_billing_usage, billable_entity: store) }

    it "responds successfully" do
      get "/active_billing/usages/#{usage.id}", headers: as_entity(store)
      expect(response).to have_http_status(:ok)
    end

    context "without a resolved entity" do
      it "responds with bad request" do
        get "/active_billing/usages/#{usage.id}"
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the usage belongs to another entity" do
      it "responds with not found" do
        get "/active_billing/usages/#{usage.id}", headers: as_entity(create(:store))
        expect(response).to have_http_status(:not_found)
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

  describe "GET /active_billing/charges/:id" do
    let(:charge) { create(:active_billing_charge, invoice: create(:active_billing_invoice, billing: billing)) }

    it "responds successfully" do
      get "/active_billing/charges/#{charge.id}", headers: as_entity(store)
      expect(response).to have_http_status(:ok)
    end

    context "without a resolved entity" do
      it "responds with bad request" do
        get "/active_billing/charges/#{charge.id}"
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the charge belongs to another entity" do
      it "responds with not found" do
        get "/active_billing/charges/#{charge.id}", headers: as_entity(create(:store))
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "portal error pages" do
    context "when the locale has no portal translations" do
      around do |example|
        I18n.available_locales += [:"pt-BR"]
        I18n.with_locale(:"pt-BR") { example.run }
      ensure
        I18n.available_locales -= [:"pt-BR"]
      end

      it "falls back to the English copy" do
        get "/active_billing/usages"
        expect(response.body).to include("Billable entity required")
      end
    end
  end
end
