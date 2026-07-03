require "rails_helper"

RSpec.describe "ActiveBilling::Api::V1 authentication", type: :request do
  let(:path) { "/active_billing/api/v1/plans" }

  around do |example|
    prev_enabled = ActiveBilling.configuration.api_enabled
    prev_authorizer = ActiveBilling.configuration.api_authorizer
    example.run
    ActiveBilling.configure do |config|
      config.api_enabled = prev_enabled
      config.api_authorizer = prev_authorizer
    end
  end

  context "when the API is disabled" do
    it "responds with not found" do
      ActiveBilling.configure { |c| c.api_enabled = false }
      get path
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when no authorizer is configured" do
    it "responds with forbidden" do
      ActiveBilling.configure do |c|
        c.api_enabled = true
        c.api_authorizer = nil
      end
      get path
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "with an invalid API key" do
    it "responds with unauthorized" do
      ActiveBilling.configure do |c|
        c.api_enabled = true
        c.api_authorizer = ->(key, _req) { key == "good" ? { key: key } : nil }
      end
      get path, headers: { "X-Api-Key" => "bad" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with a valid API key" do
    it "responds successfully" do
      ActiveBilling.configure do |c|
        c.api_enabled = true
        c.api_authorizer = ->(key, _req) { key == "good" ? { key: key } : nil }
      end
      get path, headers: { "X-Api-Key" => "good" }
      expect(response).to have_http_status(:ok)
    end
  end
end
