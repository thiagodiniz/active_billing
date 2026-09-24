require "rails_helper"

RSpec.describe ActiveBilling::Providers::Abacatepay do
  subject(:adapter) { described_class.new(settings) }

  let(:settings) { { api_key: "abc_dev_key", webhook_secret: "whsec_abacate" } }
  let(:base_url) { "https://api.abacatepay.com/v2" }
  let(:auth_headers) { { "Authorization" => "Bearer abc_dev_key", "Content-Type" => "application/json" } }

  let(:plan_uuid) { "11111111-1111-4111-8111-111111111111" }
  let(:billing_uuid) { "22222222-2222-4222-8222-222222222222" }
  let(:invoice_uuid) { "33333333-3333-4333-8333-333333333333" }
  let(:charge_uuid) { "44444444-4444-4444-8444-444444444444" }
  let(:payer) { { name: "Daniel", email: "daniel@example.com", cellphone: "(11) 4002-8922", taxId: "123.456.789-01" } }

  let(:store) { build_stubbed(:store, name: "Daniel") }
  let(:account) do
    build_stubbed(:active_billing_provider_account, provider: "abacatepay", billable_entity: store,
                                                    external_customer_id: "cust_123", metadata: payer.stringify_keys)
  end
  let(:plan) do
    build_stubbed(:active_billing_plan, uuid: plan_uuid, name: "Pro", price_in_cents: 2_990, interval: "monthly")
  end
  let(:plan_reference) do
    build_stubbed(:active_billing_provider_reference, provider: "abacatepay", external_id: "prod_1", record: plan)
  end
  let(:billing) { build_stubbed(:active_billing_billing, uuid: billing_uuid, plan: plan) }
  let(:invoice) do
    build_stubbed(:active_billing_invoice, uuid: invoice_uuid, amount_in_cents: 5_000, description: "Invoice #1")
  end
  let(:charge) { build_stubbed(:active_billing_charge, uuid: charge_uuid, invoice: invoice, external_id: "pix_char_1") }

  def success(data)
    { status: 200, body: { data: data, success: true, error: nil }.to_json,
      headers: { "Content-Type" => "application/json" } }
  end

  describe "#initialize" do
    context "without an api_key" do
      let(:settings) { { webhook_secret: "x" } }

      it "raises ConfigurationError on first request" do
        stub_request(:post, "#{base_url}/customers/create")
        expect do
          adapter.create_customer(account)
        end.to raise_error(ActiveBilling::Providers::ConfigurationError, /api_key/)
      end
    end
  end

  describe "#create_customer" do
    let!(:stub) do
      stub_request(:post, "#{base_url}/customers/create")
        .with(headers: auth_headers,
              body: { name: "Daniel", email: "daniel@example.com", cellphone: "(11) 4002-8922",
                      taxId: "123.456.789-01" }.to_json)
        .to_return(success(id: "cust_abc", metadata: { email: "daniel@example.com" }))
    end

    it "posts the customer built from account metadata" do
      adapter.create_customer(account)
      expect(stub).to have_been_requested
    end

    it "returns the customer id" do
      expect(adapter.create_customer(account).external_id).to eq("cust_abc")
    end

    it "keeps the raw response" do
      expect(adapter.create_customer(account).raw).to include("id" => "cust_abc")
    end

    context "when the billable entity responds to customer fields" do
      let!(:stub) do
        stub_request(:post, "#{base_url}/customers/create")
          .with(body: { name: "Store Name", email: "store@example.com", cellphone: "(11) 4002-8922",
                        taxId: "123.456.789-01" }.to_json)
          .to_return(success(id: "cust_abc"))
      end

      let(:entity) { Struct.new(:name, :email).new("Store Name", "store@example.com") }

      before { allow(account).to receive(:billable_entity).and_return(entity) }

      it "prefers the entity over metadata" do
        adapter.create_customer(account)
        expect(stub).to have_been_requested
      end
    end

    context "when the API returns an error" do
      let!(:stub) do
        stub_request(:post, "#{base_url}/customers/create")
          .to_return(status: 400, body: { error: "email is required" }.to_json)
      end

      it "raises ApiError with the code" do
        expect { adapter.create_customer(account) }
          .to raise_error(ActiveBilling::Providers::ApiError, "email is required") { |e| expect(e.code).to eq(400) }
      end
    end

    context "when the API returns 200 with an error body" do
      let!(:stub) do
        stub_request(:post, "#{base_url}/customers/create")
          .to_return(status: 200, body: { data: nil, error: "invalid taxId" }.to_json)
      end

      it "raises ApiError" do
        expect { adapter.create_customer(account) }.to raise_error(ActiveBilling::Providers::ApiError, "invalid taxId")
      end
    end
  end

  describe "#update_customer" do
    it "raises NotSupported" do
      expect { adapter.update_customer(account) }.to raise_error(ActiveBilling::Providers::NotSupported)
    end
  end

  describe "#create_plan" do
    let!(:stub) do
      stub_request(:post, "#{base_url}/products/create")
        .with(headers: auth_headers,
              body: { externalId: "11111111-1111-4111-8111-111111111111", name: "Pro", price: 2_990, currency: "BRL",
                      cycle: "MONTHLY" }.to_json)
        .to_return(success(id: "prod_1", externalId: "11111111-1111-4111-8111-111111111111"))
    end

    it "posts a recurring product" do
      adapter.create_plan(plan)
      expect(stub).to have_been_requested
    end

    it "returns the product id" do
      expect(adapter.create_plan(plan).external_id).to eq("prod_1")
    end

    context "when the plan is yearly" do
      let(:plan) do
        build_stubbed(:active_billing_plan, uuid: plan_uuid, name: "Pro", price_in_cents: 2_990, interval: "yearly")
      end
      let!(:stub) do
        stub_request(:post, "#{base_url}/products/create")
          .with(body: hash_including("cycle" => "ANNUALLY"))
          .to_return(success(id: "prod_1"))
      end

      it "uses the ANNUALLY cycle" do
        adapter.create_plan(plan)
        expect(stub).to have_been_requested
      end
    end
  end

  describe "#update_plan" do
    it "raises NotSupported" do
      expect { adapter.update_plan(plan, plan_reference) }.to raise_error(ActiveBilling::Providers::NotSupported)
    end
  end

  describe "#archive_plan" do
    let!(:stub) do
      stub_request(:post, "#{base_url}/products/delete")
        .with(headers: auth_headers, body: { id: "prod_1" }.to_json)
        .to_return(success(id: "prod_1", deleted: true))
    end

    it "deletes the product" do
      adapter.archive_plan(plan, plan_reference)
      expect(stub).to have_been_requested
    end

    it "returns the archived status" do
      expect(adapter.archive_plan(plan, plan_reference).status).to eq("archived")
    end
  end

  describe "#create_subscription" do
    let(:settings) { super().merge(return_url: "https://app.test/back", completion_url: "https://app.test/done") }
    let(:expected_body) do
      { items: [{ id: "prod_1", quantity: 1 }], customerId: "cust_123", externalId: billing_uuid, methods: ["CARD"],
        metadata: { billing_uuid: billing_uuid }, returnUrl: "https://app.test/back", completionUrl: "https://app.test/done" }
    end
    let!(:stub) do
      stub_request(:post, "#{base_url}/subscriptions/create")
        .with(headers: auth_headers, body: expected_body.to_json)
        .to_return(success(id: "bill_1", url: "https://app.abacatepay.com/pay/bill_1", status: "PENDING"))
    end

    it "posts a subscription checkout" do
      adapter.create_subscription(billing, account, plan_reference)
      expect(stub).to have_been_requested
    end

    it "returns the checkout id, url and pending status" do
      result = adapter.create_subscription(billing, account, plan_reference)
      expect(result.to_h).to include(external_id: "bill_1", status: "pending", url: "https://app.abacatepay.com/pay/bill_1")
    end
  end

  describe "#update_subscription" do
    let(:reference) do
      build_stubbed(:active_billing_provider_reference, provider: "abacatepay", external_id: "bill_1", record: billing,
                                                        metadata: { "last_webhook" => last_webhook })
    end
    let(:last_webhook) do
      { "event" => "subscription.completed", "data" => { "subscription" => { "id" => "subs_1" } } }
    end

    before { allow(plan).to receive(:provider_reference_for).with(:abacatepay).and_return(plan_reference) }

    let!(:stub) do
      stub_request(:post, "#{base_url}/subscriptions/change-plan")
        .with(headers: auth_headers, body: { subscriptionId: "subs_1", productId: "prod_1" }.to_json)
        .to_return(success(id: "subs_1", status: "ACTIVE"))
    end

    it "changes the plan of the activated subscription" do
      adapter.update_subscription(billing, reference)
      expect(stub).to have_been_requested
    end

    it "keeps the checkout id as external id" do
      expect(adapter.update_subscription(billing, reference).external_id).to eq("bill_1")
    end

    context "when the subscription was never activated" do
      let(:reference) do
        build_stubbed(:active_billing_provider_reference, provider: "abacatepay", external_id: "bill_1",
                                                          record: billing)
      end

      it "raises an error" do
        expect do
          adapter.update_subscription(billing, reference)
        end.to raise_error(ActiveBilling::Providers::Error, /not been activated/)
      end
    end
  end

  describe "#cancel_subscription" do
    let(:reference) do
      build_stubbed(:active_billing_provider_reference, provider: "abacatepay", external_id: "bill_1", record: billing,
                                                        metadata: { "subscription_id" => "subs_1" })
    end
    let!(:stub) do
      stub_request(:post, "#{base_url}/subscriptions/cancel")
        .with(headers: auth_headers, body: { subscriptionId: "subs_1", cancelPolicy: "NOW" }.to_json)
        .to_return(success(id: "subs_1", status: "CANCELLED"))
    end

    it "cancels the subscription" do
      adapter.cancel_subscription(billing, reference)
      expect(stub).to have_been_requested
    end

    it "returns the cancelled status" do
      expect(adapter.cancel_subscription(billing, reference).status).to eq("cancelled")
    end
  end

  describe "#create_payment" do
    let(:expected_body) do
      { method: "PIX",
        data: { amount: 5_000, description: "Invoice #1", externalId: charge_uuid,
                metadata: { charge_uuid: charge_uuid, invoice_uuid: invoice_uuid }, customer: payer } }
    end
    let!(:stub) do
      stub_request(:post, "#{base_url}/transparents/create")
        .with(headers: auth_headers, body: expected_body.to_json)
        .to_return(success(id: "pix_char_1", status: "PENDING", brCode: "000201",
                           brCodeBase64: "data:image/png;base64,x"))
    end

    it "creates a transparent PIX charge" do
      adapter.create_payment(charge, account)
      expect(stub).to have_been_requested
    end

    it "returns the pending payment" do
      expect(adapter.create_payment(charge, account).to_h).to include(external_id: "pix_char_1", status: "pending")
    end

    it "keeps the PIX code in raw" do
      expect(adapter.create_payment(charge, account).raw).to include("brCode" => "000201")
    end

    context "with a pix_expires_in setting" do
      let(:settings) { super().merge(pix_expires_in: 3600) }
      let!(:stub) do
        stub_request(:post, "#{base_url}/transparents/create")
          .with(body: hash_including("data" => hash_including("expiresIn" => 3600)))
          .to_return(success(id: "pix_char_1", status: "PENDING"))
      end

      it "sends expiresIn" do
        adapter.create_payment(charge, account)
        expect(stub).to have_been_requested
      end
    end

    context "when the payer data is incomplete" do
      let(:account) do
        build_stubbed(:active_billing_provider_account, provider: "abacatepay", billable_entity: store,
                                                        metadata: { "email" => "a@b.c" })
      end
      let!(:stub) do
        stub_request(:post, "#{base_url}/transparents/create")
          .with { |request| !JSON.parse(request.body)["data"].key?("customer") }
          .to_return(success(id: "pix_char_1", status: "PENDING"))
      end

      it "omits the customer" do
        adapter.create_payment(charge, account)
        expect(stub).to have_been_requested
      end
    end

    context "when the configured currency is not BRL" do
      before { allow(ActiveBilling.configuration).to receive(:currency).and_return(:USD) }

      it "raises ConfigurationError" do
        expect do
          adapter.create_payment(charge, account)
        end.to raise_error(ActiveBilling::Providers::ConfigurationError, /BRL/)
      end

      it "does not call the API" do
        expect { adapter.create_payment(charge, account) }.to raise_error(ActiveBilling::Providers::ConfigurationError)
        expect(stub).not_to have_been_requested
      end
    end
  end

  describe "#fetch_payment" do
    def stub_check(status)
      stub_request(:get, "#{base_url}/transparents/check?id=pix_char_1")
        .with(headers: { "Authorization" => "Bearer abc_dev_key" })
        .to_return(success(id: "pix_char_1", status: status, expiresAt: "2026-03-04T15:48:59.876Z"))
    end

    it "requests the status endpoint" do
      stub = stub_check("PENDING")
      adapter.fetch_payment(charge)
      expect(stub).to have_been_requested
    end

    described_class::PAYMENT_STATUSES.each do |remote, local|
      context "when the status is #{remote}" do
        before { stub_check(remote) }

        it { expect(adapter.fetch_payment(charge).status).to eq(local) }
      end
    end

    context "when the status is unknown" do
      before { stub_check("WHATEVER") }

      it "raises an error" do
        expect do
          adapter.fetch_payment(charge)
        end.to raise_error(ActiveBilling::Providers::Error, /unknown payment status/)
      end
    end

    context "when the API returns 401" do
      before do
        stub_request(:get, "#{base_url}/transparents/check?id=pix_char_1")
          .to_return(status: 401, body: { error: "Token inválido" }.to_json)
      end

      it "raises ApiError" do
        expect { adapter.fetch_payment(charge) }.to raise_error(ActiveBilling::Providers::ApiError, "Token inválido")
      end
    end
  end

  describe "#cancel_payment" do
    it "raises NotSupported" do
      expect { adapter.cancel_payment(charge) }.to raise_error(ActiveBilling::Providers::NotSupported)
    end
  end

  describe "#verify_webhook!" do
    let(:payload) { { event: "transparent.completed" }.to_json }
    let(:headers) { { "QUERY_STRING" => "webhookSecret=whsec_abacate" } }

    it "accepts the configured webhookSecret" do
      expect { adapter.verify_webhook!(payload, headers) }.not_to raise_error
    end

    context "with the secret given directly" do
      let(:headers) { { "webhookSecret" => "whsec_abacate" } }

      it { expect { adapter.verify_webhook!(payload, headers) }.not_to raise_error }
    end

    context "with a wrong secret" do
      let(:headers) { { "QUERY_STRING" => "webhookSecret=nope" } }

      it "raises InvalidWebhookSignature" do
        expect { adapter.verify_webhook!(payload, headers) }.to raise_error(ActiveBilling::Providers::InvalidWebhookSignature)
      end
    end

    context "without a secret" do
      let(:headers) { {} }

      it "raises InvalidWebhookSignature" do
        expect { adapter.verify_webhook!(payload, headers) }.to raise_error(ActiveBilling::Providers::InvalidWebhookSignature)
      end
    end

    context "without a configured webhook_secret" do
      let(:settings) { { api_key: "abc_dev_key" } }

      it "raises ConfigurationError" do
        expect { adapter.verify_webhook!(payload, headers) }.to raise_error(ActiveBilling::Providers::ConfigurationError)
      end
    end

    context "with an X-Webhook-Signature header" do
      let(:settings) { super().merge(signature_key: "sig_key") }
      let(:signature) { Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", "sig_key", payload)) }
      let(:headers) { { "QUERY_STRING" => "webhookSecret=whsec_abacate", "X-Webhook-Signature" => signature } }

      it "accepts a valid signature" do
        expect { adapter.verify_webhook!(payload, headers) }.not_to raise_error
      end

      context "when the signature is invalid" do
        let(:signature) { "bogus" }

        it "raises InvalidWebhookSignature" do
          expect do
            adapter.verify_webhook!(payload,
                                    headers)
          end.to raise_error(ActiveBilling::Providers::InvalidWebhookSignature, /X-Webhook-Signature/)
        end
      end

      context "when verify_signature is disabled" do
        let(:settings) { super().merge(verify_signature: false) }
        let(:signature) { "bogus" }

        it { expect { adapter.verify_webhook!(payload, headers) }.not_to raise_error }
      end
    end
  end

  describe "#parse_webhook" do
    def payload_for(event, data)
      { id: "log_1", event: event, apiVersion: 2, devMode: false, createdAt: "2024-12-06T20:00:05.000Z",
        data: data }.to_json
    end

    let(:event) { adapter.parse_webhook(payload, {}) }

    context "with transparent.completed" do
      let(:payload) { payload_for("transparent.completed", transparent: { id: "pix_char_1", status: "PAID" }) }

      it { expect(event.type).to eq(:payment_paid) }
      it { expect(event.external_id).to eq("pix_char_1") }
      it { expect(event.occurred_at).to eq(Time.zone.parse("2024-12-06T20:00:05.000Z")) }
      it { expect(event.raw).to include("event" => "transparent.completed") }
    end

    context "with transparent.refunded" do
      let(:payload) { payload_for("transparent.refunded", transparent: { id: "pix_char_1", status: "REFUNDED" }) }

      it { expect(event.type).to eq(:payment_cancelled) }
    end

    context "with checkout.completed" do
      let(:payload) { payload_for("checkout.completed", checkout: { id: "bill_1", status: "PAID" }) }

      it { expect(event.type).to eq(:payment_paid) }
      it { expect(event.external_id).to eq("bill_1") }
    end

    context "with checkout.refunded" do
      let(:payload) { payload_for("checkout.refunded", checkout: { id: "bill_1", status: "REFUNDED" }) }

      it { expect(event.type).to eq(:payment_cancelled) }
    end

    context "with subscription.completed" do
      let(:payload) do
        payload_for("subscription.completed", subscription: { id: "subs_1" }, checkout: { id: "bill_1" })
      end

      it { expect(event.type).to eq(:subscription_created) }
      it { expect(event.external_id).to eq("bill_1") }
      it { expect(event.raw.dig("data", "subscription", "id")).to eq("subs_1") }
    end

    context "with subscription.trial_started" do
      let(:payload) do
        payload_for("subscription.trial_started", subscription: { id: "subs_1" }, checkout: { id: "bill_1" })
      end

      it { expect(event.type).to eq(:subscription_created) }
    end

    %w[subscription.renewed subscription.plan_changed subscription.payment_failed].each do |name|
      context "with #{name}" do
        let(:payload) { payload_for(name, subscription: { id: "subs_1" }, checkout: { id: "bill_1" }) }

        it { expect(event.type).to eq(:subscription_updated) }
      end
    end

    context "with subscription.cancelled" do
      let(:payload) do
        payload_for("subscription.cancelled", subscription: { id: "subs_1" }, checkout: { id: "bill_1" })
      end

      it { expect(event.type).to eq(:subscription_cancelled) }
      it { expect(event.external_id).to eq("bill_1") }
    end

    context "when the subscription event has no checkout" do
      let(:payload) { payload_for("subscription.cancelled", subscription: { id: "subs_1" }) }

      it { expect(event.external_id).to eq("subs_1") }
    end

    context "with an unknown event" do
      let(:payload) { payload_for("transparent.disputed", transparent: { id: "pix_char_1" }) }

      it { expect(event.type).to eq(:ignored) }
    end

    context "with invalid JSON" do
      let(:payload) { "not json" }

      it { expect(event.type).to eq(:ignored) }
    end
  end

  describe "registry" do
    it "is registered as :abacatepay" do
      expect(ActiveBilling::Providers.fetch(:abacatepay)).to eq(described_class)
    end
  end
end
