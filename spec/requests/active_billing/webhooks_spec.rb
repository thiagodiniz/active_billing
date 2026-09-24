require "rails_helper"

RSpec.describe "ActiveBilling::Webhooks", :providers, type: :request do
  let(:charge) { create(:active_billing_charge, :synced) }
  let(:payload) { { type: "payment_paid", id: charge.external_id }.to_json }
  let(:headers) { { "CONTENT_TYPE" => "application/json", "X-Test-Signature" => "whsec_test" } }

  describe "POST /active_billing/webhooks/:provider" do
    it "applies the event and responds ok" do
      post "/active_billing/webhooks/test", params: payload, headers: headers
      expect(response).to have_http_status(:ok)
      expect(charge.reload).to be_paid
    end

    context "with an invalid signature" do
      it "responds unauthorized" do
        post "/active_billing/webhooks/test", params: payload, headers: headers.except("X-Test-Signature")
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with the abacatepay provider" do
      let!(:charge) { create(:active_billing_charge, :synced, provider: "abacatepay", external_id: "pix_char_1") }
      let(:payload) do
        { event: "transparent.completed", data: { transparent: { id: "pix_char_1", status: "PAID" } } }.to_json
      end

      before do
        ActiveBilling.configuration.providers[:abacatepay] = { api_key: "abc_dev_key", webhook_secret: "whsec_abacate" }
        ActiveBilling.configuration.provider_sync_enabled = false
      end

      it "authenticates with the webhookSecret query parameter" do
        post "/active_billing/webhooks/abacatepay?webhookSecret=whsec_abacate", params: payload, headers: headers
        expect(response).to have_http_status(:ok)
        expect(charge.reload).to be_paid
      end

      it "rejects a wrong webhookSecret" do
        post "/active_billing/webhooks/abacatepay?webhookSecret=nope", params: payload, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an unknown provider" do
      it "responds not found" do
        post "/active_billing/webhooks/nope", params: payload, headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
