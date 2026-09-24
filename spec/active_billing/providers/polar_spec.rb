require "rails_helper"

module ActiveBilling
  RSpec.describe Providers::Polar do
    subject(:adapter) { described_class.new(settings) }

    let(:settings) { { api_key: "polar_oat_test", webhook_secret: webhook_secret, success_url: "https://app.test/ok" } }
    let(:webhook_secret) { "whsec_#{Base64.strict_encode64('super-secret-key')}" }
    let(:base_url) { "https://api.polar.sh/v1" }
    let(:auth_headers) { { "Authorization" => "Bearer polar_oat_test", "Content-Type" => "application/json" } }

    let(:store) { create(:store, name: "Acme") }
    let(:account) do
      create(:active_billing_provider_account, :synced, provider: "polar", billable_entity: store,
                                                        external_customer_id: "cus_1")
    end
    let(:plan) { create(:active_billing_plan, name: "Pro", price_in_cents: 4_990, interval: "yearly") }
    let(:plan_reference) do
      create(:active_billing_provider_reference, record: plan, provider: "polar", external_id: "prod_1")
    end
    let(:billing) { create(:active_billing_billing, billable_entity: store, plan: plan) }
    let(:checkout_response) do
      { id: "chk_1", status: "open", url: "https://polar.sh/checkout/chk_1", customer_id: "cus_1",
        subscription_id: nil, expires_at: "2026-01-02T00:00:00Z" }
    end

    around do |example|
      configuration = ActiveBilling.configuration
      original = configuration.dup
      configuration.providers = { polar: settings }
      configuration.provider_sync_enabled = false
      example.run
    ensure
      ActiveBilling.configuration = original
    end

    def stub_polar(method, path, body:, status: 200, request: nil)
      stub = stub_request(method, "#{base_url}#{path}").with(headers: auth_headers.slice("Authorization"))
      stub = stub.with(body: hash_including(request)) if request
      stub.to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
    end

    describe ".provider_name" do
      it { expect(described_class.provider_name).to eq(:polar) }
    end

    describe "registration" do
      it { expect(Providers.fetch(:polar)).to eq(described_class) }
    end

    describe "#create_customer" do
      let!(:stub) do
        stub_polar(:post, "/customers", body: { id: "cus_1", email: "acme@test.com", name: "Acme" },
                                        request: { "name" => "Acme", "external_id" => "Store:#{store.id}" })
      end

      it "returns the customer id" do
        expect(adapter.create_customer(account).external_id).to eq("cus_1")
      end

      it "sends the authenticated request" do
        adapter.create_customer(account)
        expect(stub).to have_been_requested
      end

      context "without api_key" do
        let(:settings) { { webhook_secret: webhook_secret } }

        it "raises ConfigurationError" do
          expect { adapter.create_customer(account) }.to raise_error(Providers::ConfigurationError)
        end
      end

      context "when sandbox is enabled" do
        let(:settings) { super().merge(sandbox: true) }
        let(:base_url) { "https://sandbox-api.polar.sh/v1" }

        it "hits the sandbox host" do
          adapter.create_customer(account)
          expect(stub).to have_been_requested
        end
      end

      context "when the API rejects the request" do
        let!(:stub) do
          stub_polar(:post, "/customers", status: 422,
                                          body: { detail: [{ loc: %w[body email], msg: "field required" }] })
        end

        it "raises ApiError with the validation detail" do
          expect { adapter.create_customer(account) }
            .to raise_error(Providers::ApiError, /HTTP 422 body.email: field required/)
        end
      end

      context "when the API returns a named error" do
        let!(:stub) { stub_polar(:post, "/customers", status: 403, body: { error: "NotPermitted", detail: "nope" }) }

        it "exposes the error code" do
          expect { adapter.create_customer(account) }
            .to raise_error(Providers::ApiError) { |error| expect(error.code).to eq("NotPermitted") }
        end
      end
    end

    describe "#update_customer" do
      let!(:stub) { stub_polar(:patch, "/customers/cus_1", body: { id: "cus_1" }, request: { "name" => "Acme" }) }

      it "patches the customer" do
        adapter.update_customer(account)
        expect(stub).to have_been_requested
      end
    end

    describe "#create_plan" do
      let!(:stub) do
        stub_polar(:post, "/products",
                   body: { id: "prod_1", is_archived: false, recurring_interval: "year", prices: [{ id: "price_1" }] },
                   request: { "name" => "Pro", "recurring_interval" => "year",
                              "prices" => [{ "amount_type" => "fixed", "price_amount" => 4_990,
                                             "price_currency" => "brl" }] })
      end

      it "returns the product id" do
        expect(adapter.create_plan(plan).external_id).to eq("prod_1")
      end

      it "keeps the price id in raw" do
        expect(adapter.create_plan(plan).raw).to include("price_id" => "price_1")
      end

      it "posts a recurring product" do
        adapter.create_plan(plan)
        expect(stub).to have_been_requested
      end
    end

    describe "#update_plan" do
      let!(:stub) do
        stub_polar(:patch, "/products/prod_1", body: { id: "prod_1", is_archived: false, prices: [] },
                                               request: { "name" => "Pro", "is_archived" => false })
      end

      it "patches the product" do
        adapter.update_plan(plan, plan_reference)
        expect(stub).to have_been_requested
      end

      it { expect(adapter.update_plan(plan, plan_reference).status).to eq("active") }
    end

    describe "#archive_plan" do
      let!(:stub) do
        stub_polar(:patch, "/products/prod_1", body: { id: "prod_1", is_archived: true },
                                               request: { "is_archived" => true })
      end

      it "archives the product" do
        adapter.archive_plan(plan, plan_reference)
        expect(stub).to have_been_requested
      end

      it { expect(adapter.archive_plan(plan, plan_reference).status).to eq("archived") }
    end

    describe "#create_subscription" do
      subject(:result) { adapter.create_subscription(billing, account, plan_reference) }

      let!(:stub) do
        stub_polar(:post, "/checkouts", body: checkout_response,
                                        request: { "products" => ["prod_1"], "customer_id" => "cus_1",
                                                   "success_url" => "https://app.test/ok" })
      end

      it { expect(result.external_id).to eq("chk_1") }
      it { expect(result.status).to eq("pending") }
      it { expect(result.url).to eq("https://polar.sh/checkout/chk_1") }

      it "creates a checkout for the product" do
        result
        expect(stub).to have_been_requested
      end
    end

    describe "#update_subscription" do
      let(:reference) do
        create(:active_billing_provider_reference, record: billing, provider: "polar", external_id: "chk_1",
                                                   metadata: { "subscription_id" => "sub_1" })
      end
      let!(:stub) do
        stub_polar(:patch, "/subscriptions/sub_1", body: { id: "sub_1", status: "active", product_id: "prod_1" },
                                                   request: { "product_id" => "prod_1" })
      end

      before { plan_reference }

      it "patches the subscription product" do
        adapter.update_subscription(billing, reference)
        expect(stub).to have_been_requested
      end

      it "keeps the checkout id as external id" do
        expect(adapter.update_subscription(billing, reference).external_id).to eq("chk_1")
      end

      context "when the checkout has not been completed" do
        let(:reference) do
          create(:active_billing_provider_reference, record: billing, provider: "polar", external_id: "chk_1")
        end
        let!(:checkout_stub) { stub_polar(:get, "/checkouts/chk_1", body: checkout_response) }

        it { expect(adapter.update_subscription(billing, reference).status).to eq("pending") }

        it "does not patch any subscription" do
          adapter.update_subscription(billing, reference)
          expect(stub).not_to have_been_requested
        end
      end
    end

    describe "#cancel_subscription" do
      let(:reference) do
        create(:active_billing_provider_reference, record: billing, provider: "polar", external_id: "chk_1")
      end
      let!(:checkout_stub) do
        stub_polar(:get, "/checkouts/chk_1", body: checkout_response.merge(subscription_id: "sub_1"))
      end
      let!(:stub) do
        stub_polar(:patch, "/subscriptions/sub_1", body: { id: "sub_1", status: "active", cancel_at_period_end: true },
                                                   request: { "cancel_at_period_end" => true })
      end

      it "resolves the subscription through the checkout" do
        adapter.cancel_subscription(billing, reference)
        expect(checkout_stub).to have_been_requested
      end

      it "cancels at period end" do
        adapter.cancel_subscription(billing, reference)
        expect(stub).to have_been_requested
      end

      it { expect(adapter.cancel_subscription(billing, reference).status).to eq("cancelled") }
      it { expect(adapter.cancel_subscription(billing, reference).raw).to include("subscription_id" => "sub_1") }

      context "with revoke enabled" do
        let(:settings) { super().merge(revoke: true) }
        let!(:stub) do
          stub_polar(:patch, "/subscriptions/sub_1", body: { id: "sub_1", status: "canceled" },
                                                     request: { "revoke" => true })
        end

        it "revokes immediately" do
          adapter.cancel_subscription(billing, reference)
          expect(stub).to have_been_requested
        end
      end

      context "when the checkout never produced a subscription" do
        let!(:checkout_stub) { stub_polar(:get, "/checkouts/chk_1", body: checkout_response.merge(status: "expired")) }

        it { expect(adapter.cancel_subscription(billing, reference).status).to eq("cancelled") }

        it "does not call the subscriptions endpoint" do
          adapter.cancel_subscription(billing, reference)
          expect(stub).not_to have_been_requested
        end
      end
    end

    describe "#create_payment" do
      subject(:result) { adapter.create_payment(charge, account) }

      let(:invoice) do
        create(:active_billing_invoice, resource: store, billing: billing, amount_in_cents: 12_345,
                                        description: "March")
      end
      let(:charge) { create(:active_billing_charge, resource: store, invoice: invoice) }
      let!(:product_stub) do
        stub_polar(:post, "/products", body: { id: "prod_pay" },
                                       request: { "name" => "March", "recurring_interval" => nil,
                                                  "prices" => [{ "amount_type" => "fixed", "price_amount" => 12_345,
                                                                 "price_currency" => "brl" }] })
      end
      let!(:checkout_stub) do
        stub_polar(:post, "/checkouts", body: checkout_response,
                                        request: { "products" => ["prod_pay"], "customer_id" => "cus_1",
                                                   "prices" => { "prod_pay" => [{ "amount_type" => "fixed",
                                                                                  "price_amount" => 12_345,
                                                                                  "price_currency" => "brl" }] } })
      end

      it { expect(result.external_id).to eq("chk_1") }
      it { expect(result.status).to eq("pending") }
      it { expect(result.url).to eq("https://polar.sh/checkout/chk_1") }
      it { expect(result.raw).to include("product_id" => "prod_pay") }

      it "creates a one-time product" do
        result
        expect(product_stub).to have_been_requested
      end

      it "creates the checkout" do
        result
        expect(checkout_stub).to have_been_requested
      end

      context "with a configured payment_product_id" do
        let(:settings) { super().merge(payment_product_id: "prod_pay") }

        it "does not create a product" do
          result
          expect(product_stub).not_to have_been_requested
        end

        it "still creates the checkout" do
          result
          expect(checkout_stub).to have_been_requested
        end
      end
    end

    describe "#fetch_payment" do
      let(:charge) { create(:active_billing_charge, :synced, provider: "polar", external_id: "chk_1") }

      {
        "open" => "pending",
        "confirmed" => "processing",
        "succeeded" => "paid",
        "failed" => "failed",
        "expired" => "expired"
      }.each do |polar_status, status|
        context "when the checkout is #{polar_status}" do
          before { stub_polar(:get, "/checkouts/chk_1", body: checkout_response.merge(status: polar_status)) }

          it { expect(adapter.fetch_payment(charge).status).to eq(status) }
        end
      end

      context "when the checkout does not exist" do
        before do
          stub_polar(:get, "/checkouts/chk_1", status: 404, body: { error: "ResourceNotFound", detail: "gone" })
        end

        it "raises ApiError" do
          expect { adapter.fetch_payment(charge) }.to raise_error(Providers::ApiError, /HTTP 404 gone/)
        end
      end
    end

    describe "#cancel_payment" do
      let(:charge) { build_stubbed(:active_billing_charge) }

      it "raises NotSupported" do
        expect { adapter.cancel_payment(charge) }.to raise_error(Providers::NotSupported)
      end
    end

    describe "#verify_webhook!" do
      let(:payload) { { type: "order.paid", data: { id: "ord_1" } }.to_json }
      let(:timestamp) { Time.now.to_i.to_s }
      let(:signing_key) { "super-secret-key" }
      let(:signature) do
        "v1,#{Base64.strict_encode64(OpenSSL::HMAC.digest('SHA256', signing_key, "msg_1.#{timestamp}.#{payload}"))}"
      end
      let(:headers) { { "Webhook-Id" => "msg_1", "Webhook-Timestamp" => timestamp, "Webhook-Signature" => signature } }

      it { expect(adapter.verify_webhook!(payload, headers)).to be(true) }

      context "with lowercase header names" do
        let(:headers) do
          { "webhook-id" => "msg_1", "webhook-timestamp" => timestamp, "webhook-signature" => signature }
        end

        it { expect(adapter.verify_webhook!(payload, headers)).to be(true) }
      end

      context "with a legacy secret keyed by the raw whsec_ string" do
        let(:signing_key) { webhook_secret }

        it { expect(adapter.verify_webhook!(payload, headers)).to be(true) }
      end

      context "with several signatures in the header" do
        let(:headers) { super().merge("Webhook-Signature" => "v1,bogus #{signature}") }

        it { expect(adapter.verify_webhook!(payload, headers)).to be(true) }
      end

      context "with a wrong secret" do
        let(:signing_key) { "other" }

        it "raises InvalidWebhookSignature" do
          expect { adapter.verify_webhook!(payload, headers) }.to raise_error(Providers::InvalidWebhookSignature)
        end
      end

      context "with a tampered payload" do
        it "raises InvalidWebhookSignature" do
          expect { adapter.verify_webhook!("{}", headers) }.to raise_error(Providers::InvalidWebhookSignature)
        end
      end

      context "with a stale timestamp" do
        let(:timestamp) { (Time.now.to_i - 3_600).to_s }

        it "raises InvalidWebhookSignature" do
          expect { adapter.verify_webhook!(payload, headers) }.to raise_error(Providers::InvalidWebhookSignature)
        end
      end

      context "without signature headers" do
        it "raises InvalidWebhookSignature" do
          expect { adapter.verify_webhook!(payload, {}) }.to raise_error(Providers::InvalidWebhookSignature)
        end
      end

      context "without webhook_secret" do
        let(:settings) { { api_key: "polar_oat_test" } }

        it "raises ConfigurationError" do
          expect { adapter.verify_webhook!(payload, headers) }.to raise_error(Providers::ConfigurationError)
        end
      end
    end

    describe "#parse_webhook" do
      subject(:event) { adapter.parse_webhook(payload.to_json, {}) }

      let(:payload) { { type: type, timestamp: "2026-03-01T12:00:00Z", data: data } }
      let(:data) { { id: "obj_1", checkout_id: "chk_1" } }

      {
        "open" => :payment_pending,
        "confirmed" => :payment_processing,
        "succeeded" => :payment_paid,
        "failed" => :payment_failed,
        "expired" => :payment_expired
      }.each do |status, expected_type|
        context "with checkout.updated (#{status})" do
          let(:type) { "checkout.updated" }
          let(:data) { { id: "chk_1", status: status } }

          it { expect(event.type).to eq(expected_type) }
          it { expect(event.external_id).to eq("chk_1") }
        end
      end

      context "with checkout.expired" do
        let(:type) { "checkout.expired" }
        let(:data) { { id: "chk_1", status: "expired" } }

        it { expect(event.type).to eq(:payment_expired) }
      end

      context "with order.paid" do
        let(:type) { "order.paid" }

        it { expect(event.type).to eq(:payment_paid) }
        it { expect(event.external_id).to eq("chk_1") }
        it { expect(event.occurred_at).to eq(Time.utc(2026, 3, 1, 12)) }
        it { expect(event.raw).to include("type" => "order.paid") }
      end

      context "with order.paid without a checkout" do
        let(:type) { "order.paid" }
        let(:data) { { id: "ord_1" } }

        it { expect(event.external_id).to eq("ord_1") }
      end

      {
        "subscription.created" => :subscription_created,
        "subscription.updated" => :subscription_updated,
        "subscription.active" => :subscription_updated,
        "subscription.uncanceled" => :subscription_updated,
        "subscription.cycled" => :subscription_updated,
        "subscription.past_due" => :subscription_updated,
        "subscription.paused" => :subscription_updated,
        "subscription.resumed" => :subscription_updated,
        "subscription.migrated" => :subscription_updated,
        "subscription.canceled" => :subscription_cancelled,
        "subscription.revoked" => :subscription_cancelled
      }.each do |polar_type, expected_type|
        context "with #{polar_type}" do
          let(:type) { polar_type }
          let(:data) { { id: "sub_1", checkout_id: "chk_1" } }

          it { expect(event.type).to eq(expected_type) }
          it { expect(event.external_id).to eq("chk_1") }
        end
      end

      %w[checkout.created order.created order.updated customer.created benefit_grant.created].each do |polar_type|
        context "with #{polar_type}" do
          let(:type) { polar_type }

          it { expect(event.type).to eq(:ignored) }
        end
      end

      context "with a Hash payload" do
        subject(:event) { adapter.parse_webhook(payload, {}) }

        let(:type) { "order.paid" }

        it { expect(event.type).to eq(:payment_paid) }
      end
    end
  end
end
