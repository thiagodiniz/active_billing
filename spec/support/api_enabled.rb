RSpec.shared_context "api enabled" do
  let(:api_key) { "test-key" }
  let(:api_headers) { { "X-Api-Key" => api_key } }

  around do |example|
    prev_enabled = ActiveBilling.configuration.api_enabled
    prev_authorizer = ActiveBilling.configuration.api_authorizer

    ActiveBilling.configure do |config|
      config.api_enabled = true
      config.api_authorizer = ->(key, _request) { key == "test-key" ? { key: key } : nil }
    end

    example.run

    ActiveBilling.configure do |config|
      config.api_enabled = prev_enabled
      config.api_authorizer = prev_authorizer
    end
  end
end

def json_body
  JSON.parse(response.body)
end
