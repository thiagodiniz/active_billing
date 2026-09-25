require "rails_helper"

RSpec.describe "ActiveBilling::Api::V1::Events", type: :request do
  include_context "api enabled"

  let(:store) { create(:store) }
  let(:usage) { create(:active_billing_usage, billable_entity: store) }
  let(:base) { "/active_billing/api/v1/events" }

  let(:event_params) do
    { event: { billing_usage_id: usage.id, kind: "api_call", resource_type: "Store", resource_id: store.id } }
  end

  describe "POST /events" do
    it "creates an event" do
      post base, params: event_params, headers: api_headers
      expect(response).to have_http_status(:created)
    end

    context "when the usage is closed" do
      it "responds with unprocessable entity" do
        usage.close!
        post base, params: event_params, headers: api_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /events/:id" do
    it "hard-deletes the event" do
      event = create(:active_billing_event, usage: usage)
      expect do
        delete "#{base}/#{event.id}", headers: api_headers
      end.to change(ActiveBilling::Event, :count).by(-1)
    end
  end

  describe "PATCH /events/:id" do
    it "has no update route" do
      event = create(:active_billing_event, usage: usage)
      patch "#{base}/#{event.id}", params: { event: { kind: "sms_sent" } }, headers: api_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
