require "rails_helper"

module ActiveBilling
  RSpec.describe Providers::Stripe do
    subject(:adapter) { described_class.new(settings) }

    let(:settings) do
      { api_key: "sk_test_123", webhook_secret: "whsec_test",
        success_url: "https://app.test/success", cancel_url: "https://app.test/cancel" }
    end
    let(:base_url) { "https://api.stripe.com/v1" }
    let(:auth_headers) { { "Authorization" => "Bearer sk_test_123" } }

    let(:store) { create(:store, name: "Acme") }
    let(:account) { create(:active_billing_provider_account, :synced, provider: "test", billable_entity: store) }
    let(:plan) { create(:active_billing_plan, name: "Pro", price_in_cents: 2_500, interval: "yearly") }
    let(:plan_reference) do
      create(:active_billing_provider_reference, record: plan, provider: "stripe", external_id: "prod_1",
                                                 metadata: { "price_id" => "price_1" })
    end
    let(:charge) { create(:active_billing_charge, provider: "stripe", external_id: "cs_1", state: "pending") }

    def stub_stripe(method, path, response, status: 200, body: nil)
      stub = stub_request(method, "#{base_url}#{path}").with(headers: auth_headers)
      stub = stub.with(body: body) if body
      stub.to_return(status: status, body: response.to_json, headers: { "Content-Type" => "application/json" })
    end

    def form(params)
      URI.encode_www_form(params)
    end

    it { expect(Providers.fetch(:stripe)).to eq(described_class) }
    it { expect(described_class.provider_name).to eq(:stripe) }

    describe "#create_customer" do
      let!(:request) do
        stub_stripe(:post, "/customers", { id: "cus_1", object: "customer" },
                    body: form(name: "Acme",
                               "metadata[active_billing_account_id]" => account.id,
                               "metadata[billable_entity_type]" => "Store",
                               "metadata[billable_entity_id]" => store.id))
      end

      it { expect(adapter.create_customer(account).external_id).to eq("cus_1") }
      it { expect(adapter.create_customer(account).raw).to include("object" => "customer") }

      it "sends the form-encoded request" do
        adapter.create_customer(account)
        expect(request).to have_been_requested
      end

      context "without an api_key" do
        let(:settings) { {} }

        it "raises ConfigurationError" do
          expect { adapter.create_customer(account) }.to raise_error(Providers::ConfigurationError)
        end
      end

      context "when Stripe returns an error" do
        let!(:request) do
          stub_stripe(:post, "/customers", { error: { code: "resource_missing", message: "No such customer" } },
                      status: 404)
        end

        it "raises ApiError with the code" do
          expect { adapter.create_customer(account) }
            .to raise_error(Providers::ApiError) { |error| expect(error.code).to eq("resource_missing") }
        end

        it "raises ApiError with the message" do
          expect { adapter.create_customer(account) }.to raise_error(Providers::ApiError, "No such customer")
        end
      end
    end

    describe "#update_customer" do
      let!(:request) do
        stub_stripe(:post, "/customers/#{account.external_customer_id}", { id: account.external_customer_id },
                    body: hash_including("name" => "Acme"))
      end

      it { expect(adapter.update_customer(account).external_id).to eq(account.external_customer_id) }

      it "posts to the customer path" do
        adapter.update_customer(account)
        expect(request).to have_been_requested
      end
    end

    describe "#create_plan" do
      let!(:product_request) do
        stub_stripe(:post, "/products", { id: "prod_1", active: true },
                    body: form(name: "Pro", active: true, "metadata[active_billing_plan_id]" => plan.id))
      end
      let!(:price_request) do
        stub_stripe(:post, "/prices", { id: "price_1", unit_amount: 2_500 },
                    body: form(product: "prod_1", unit_amount: 2_500, currency: "brl",
                               "recurring[interval]" => "year", "metadata[active_billing_plan_id]" => plan.id))
      end

      it { expect(adapter.create_plan(plan).external_id).to eq("prod_1") }
      it { expect(adapter.create_plan(plan).status).to eq("active") }
      it { expect(adapter.create_plan(plan).raw).to include("price_id" => "price_1") }

      it "creates the product and the recurring price" do
        adapter.create_plan(plan)
        expect(product_request).to have_been_requested
        expect(price_request).to have_been_requested
      end
    end

    describe "#update_plan" do
      let!(:product_request) do
        stub_stripe(:post, "/products/prod_1", { id: "prod_1", active: true }, body: hash_including("name" => "Pro"))
      end

      context "when the price is unchanged" do
        let!(:price_request) do
          stub_stripe(:get, "/prices/price_1",
                      { id: "price_1", unit_amount: 2_500, currency: "brl", recurring: { interval: "year" } })
        end

        it { expect(adapter.update_plan(plan, plan_reference).raw).to include("price_id" => "price_1") }

        it "does not create a new price" do
          adapter.update_plan(plan, plan_reference)
          expect(a_request(:post, "#{base_url}/prices")).not_to have_been_made
        end
      end

      context "when the price changed" do
        let!(:old_price_request) do
          stub_stripe(:get, "/prices/price_1",
                      { id: "price_1", unit_amount: 1_000, currency: "brl", recurring: { interval: "year" } })
        end
        let!(:new_price_request) do
          stub_stripe(:post, "/prices", { id: "price_2", unit_amount: 2_500 },
                      body: hash_including("unit_amount" => "2500"))
        end
        let!(:archive_request) do
          stub_stripe(:post, "/prices/price_1", { id: "price_1", active: false }, body: form(active: false))
        end

        it { expect(adapter.update_plan(plan, plan_reference).raw).to include("price_id" => "price_2") }

        it "creates a new price and archives the old one" do
          adapter.update_plan(plan, plan_reference)
          expect(new_price_request).to have_been_requested
          expect(archive_request).to have_been_requested
        end
      end
    end

    describe "#archive_plan" do
      let!(:price_request) do
        stub_stripe(:post, "/prices/price_1", { id: "price_1", active: false }, body: form(active: false))
      end
      let!(:product_request) do
        stub_stripe(:post, "/products/prod_1", { id: "prod_1", active: false }, body: form(active: false))
      end

      it { expect(adapter.archive_plan(plan, plan_reference).status).to eq("archived") }

      it "deactivates the price and the product" do
        adapter.archive_plan(plan, plan_reference)
        expect(price_request).to have_been_requested
        expect(product_request).to have_been_requested
      end
    end

    describe "#create_subscription" do
      let(:billing) { create(:active_billing_billing, plan: plan, billable_entity: store) }
      let!(:request) do
        stub_stripe(:post, "/subscriptions", { id: "sub_1", status: "active" },
                    body: form(customer: account.external_customer_id, "items[0][price]" => "price_1"))
      end

      it { expect(adapter.create_subscription(billing, account, plan_reference).external_id).to eq("sub_1") }
      it { expect(adapter.create_subscription(billing, account, plan_reference).status).to eq("active") }

      context "without a plan reference" do
        it "raises ConfigurationError" do
          expect { adapter.create_subscription(billing, account, nil) }.to raise_error(Providers::ConfigurationError)
        end
      end
    end

    describe "#update_subscription" do
      let(:billing) { create(:active_billing_billing, plan: plan, billable_entity: store) }
      let(:reference) do
        create(:active_billing_provider_reference, record: billing, provider: "stripe", external_id: "sub_1")
      end
      let!(:fetch_request) do
        stub_stripe(:get, "/subscriptions/sub_1",
                    { id: "sub_1", status: "active", items: { data: [{ id: "si_1", price: { id: current_price } }] } })
      end

      context "when the plan price is unchanged" do
        let(:current_price) { "price_1" }

        before { plan_reference }

        it { expect(adapter.update_subscription(billing, reference).status).to eq("active") }

        it "does not modify the subscription" do
          adapter.update_subscription(billing, reference)
          expect(a_request(:post, "#{base_url}/subscriptions/sub_1")).not_to have_been_made
        end
      end

      context "when the plan price changed" do
        let(:current_price) { "price_0" }
        let!(:update_request) do
          stub_stripe(:post, "/subscriptions/sub_1", { id: "sub_1", status: "active" },
                      body: form("items[0][id]" => "si_1", "items[0][price]" => "price_1"))
        end

        before { plan_reference }

        it "swaps the subscription item price" do
          adapter.update_subscription(billing, reference)
          expect(update_request).to have_been_requested
        end
      end
    end

    describe "#cancel_subscription" do
      let(:billing) { create(:active_billing_billing, plan: plan, billable_entity: store) }
      let(:reference) do
        create(:active_billing_provider_reference, record: billing, provider: "stripe", external_id: "sub_1")
      end
      let!(:request) { stub_stripe(:delete, "/subscriptions/sub_1", { id: "sub_1", status: "canceled" }) }

      it { expect(adapter.cancel_subscription(billing, reference).status).to eq("canceled") }

      it "deletes the subscription" do
        adapter.cancel_subscription(billing, reference)
        expect(request).to have_been_requested
      end
    end

    describe "#create_payment" do
      let(:invoice) { create(:active_billing_invoice, amount_in_cents: 5_000, description: "March usage") }
      let(:charge) { create(:active_billing_charge, invoice: invoice, resource: store) }
      let!(:request) do
        stub_stripe(:post, "/checkout/sessions",
                    { id: "cs_1", url: "https://checkout.stripe.com/c/pay/cs_1", status: "open",
                      payment_status: "unpaid" },
                    body: form(mode: "payment", customer: account.external_customer_id,
                               client_reference_id: charge.uuid,
                               success_url: "https://app.test/success", cancel_url: "https://app.test/cancel",
                               "line_items[0][quantity]" => 1,
                               "line_items[0][price_data][currency]" => "brl",
                               "line_items[0][price_data][unit_amount]" => 5_000,
                               "line_items[0][price_data][product_data][name]" => "March usage",
                               "metadata[active_billing_charge_id]" => charge.id,
                               "metadata[active_billing_invoice_id]" => invoice.id))
      end

      it { expect(adapter.create_payment(charge, account).external_id).to eq("cs_1") }
      it { expect(adapter.create_payment(charge, account).status).to eq("pending") }
      it { expect(adapter.create_payment(charge, account).url).to eq("https://checkout.stripe.com/c/pay/cs_1") }

      it "creates a checkout session" do
        adapter.create_payment(charge, account)
        expect(request).to have_been_requested
      end

      context "without a success_url" do
        let(:settings) { { api_key: "sk_test_123" } }

        it "raises ConfigurationError" do
          expect { adapter.create_payment(charge, account) }.to raise_error(Providers::ConfigurationError)
        end
      end
    end

    describe "#fetch_payment" do
      {
        { status: "open", payment_status: "unpaid" } => "pending",
        { status: "complete", payment_status: "paid" } => "paid",
        { status: "complete", payment_status: "no_payment_required" } => "paid",
        { status: "complete", payment_status: "unpaid" } => "pending",
        { status: "expired", payment_status: "unpaid" } => "expired"
      }.each do |session, expected|
        context "with #{session[:status]}/#{session[:payment_status]}" do
          before { stub_stripe(:get, "/checkout/sessions/cs_1", session.merge(id: "cs_1")) }

          it { expect(adapter.fetch_payment(charge).status).to eq(expected) }
        end
      end

      it "is one of the payment statuses" do
        stub_stripe(:get, "/checkout/sessions/cs_1", { id: "cs_1", status: "open", payment_status: "unpaid" })
        expect(Providers::PAYMENT_STATUSES).to include(adapter.fetch_payment(charge).status)
      end
    end

    describe "#cancel_payment" do
      let!(:request) do
        stub_stripe(:post, "/checkout/sessions/cs_1/expire",
                    { id: "cs_1", status: "expired", payment_status: "unpaid" })
      end

      it { expect(adapter.cancel_payment(charge).status).to eq("cancelled") }

      it "expires the session" do
        adapter.cancel_payment(charge)
        expect(request).to have_been_requested
      end
    end

    describe "#verify_webhook!" do
      let(:payload) { { id: "evt_1", type: "checkout.session.completed" }.to_json }
      let(:timestamp) { Time.now.to_i }
      let(:signature) { OpenSSL::HMAC.hexdigest("SHA256", "whsec_test", "#{timestamp}.#{payload}") }
      let(:headers) { { "Stripe-Signature" => "t=#{timestamp},v1=#{signature}" } }

      it { expect(adapter.verify_webhook!(payload, headers)).to be(true) }

      context "with an extra v0 signature" do
        let(:headers) { { "Stripe-Signature" => "t=#{timestamp},v1=#{signature},v0=deadbeef" } }

        it { expect(adapter.verify_webhook!(payload, headers)).to be(true) }
      end

      context "with a wrong signature" do
        let(:headers) { { "Stripe-Signature" => "t=#{timestamp},v1=#{'0' * 64}" } }

        it "raises InvalidWebhookSignature" do
          expect { adapter.verify_webhook!(payload, headers) }.to raise_error(Providers::InvalidWebhookSignature)
        end
      end

      context "with a stale timestamp" do
        let(:timestamp) { 10.minutes.ago.to_i }

        it "raises InvalidWebhookSignature" do
          expect { adapter.verify_webhook!(payload, headers) }.to raise_error(Providers::InvalidWebhookSignature)
        end
      end

      context "without the header" do
        let(:headers) { {} }

        it "raises InvalidWebhookSignature" do
          expect { adapter.verify_webhook!(payload, headers) }.to raise_error(Providers::InvalidWebhookSignature)
        end
      end

      context "with a malformed header" do
        let(:headers) { { "Stripe-Signature" => "garbage" } }

        it "raises InvalidWebhookSignature" do
          expect { adapter.verify_webhook!(payload, headers) }.to raise_error(Providers::InvalidWebhookSignature)
        end
      end

      context "without a webhook_secret" do
        let(:settings) { { api_key: "sk_test_123" } }

        it "raises ConfigurationError" do
          expect { adapter.verify_webhook!(payload, headers) }.to raise_error(Providers::ConfigurationError)
        end
      end
    end

    describe "#parse_webhook" do
      def event_for(type, object_id = "cs_1")
        { id: "evt_1", type: type, created: 1_700_000_000, data: { object: { id: object_id } } }.to_json
      end

      {
        "checkout.session.completed" => :payment_paid,
        "checkout.session.async_payment_succeeded" => :payment_paid,
        "checkout.session.async_payment_failed" => :payment_failed,
        "checkout.session.expired" => :payment_expired,
        "customer.subscription.created" => :subscription_created,
        "customer.subscription.updated" => :subscription_updated,
        "customer.subscription.deleted" => :subscription_cancelled,
        "invoice.paid" => :ignored
      }.each do |stripe_type, expected|
        context "with #{stripe_type}" do
          it { expect(adapter.parse_webhook(event_for(stripe_type), {}).type).to eq(expected) }
        end
      end

      describe "the parsed event" do
        subject(:event) { adapter.parse_webhook(event_for("checkout.session.completed"), {}) }

        it { expect(event.external_id).to eq("cs_1") }
        it { expect(event.occurred_at).to eq(Time.zone.at(1_700_000_000)) }
        it { expect(event.raw).to include("id" => "evt_1") }
      end
    end
  end
end
