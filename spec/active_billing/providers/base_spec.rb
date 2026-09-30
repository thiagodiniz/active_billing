require "rails_helper"

module ActiveBilling
  RSpec.describe Providers::Base do
    subject(:adapter) { described_class.new("api_key" => "sk_test") }

    describe "#setting" do
      it { expect(adapter.setting(:api_key)).to eq("sk_test") }
    end

    describe "#setting!" do
      context "when the setting is missing" do
        it "raises ConfigurationError" do
          expect { adapter.setting!(:webhook_secret) }.to raise_error(Providers::ConfigurationError)
        end
      end
    end

    describe ".provider_name" do
      it { expect(described_class.provider_name).to eq(:base) }
    end

    describe "interface" do
      %i[
        create_customer update_customer
        create_plan update_plan archive_plan
        create_subscription update_subscription cancel_subscription
        create_payment fetch_payment cancel_payment
        verify_webhook! parse_webhook
      ].each do |operation|
        it "#{operation} raises NotSupported by default" do
          arity = adapter.method(operation).arity
          args = Array.new(arity) { nil }
          expect { adapter.public_send(operation, *args) }.to raise_error(Providers::NotSupported)
        end
      end
    end
  end

  RSpec.describe Providers::Result do
    subject(:result) { described_class.new(external_id: 42, status: :paid) }

    it { expect(result.external_id).to eq("42") }
    it { expect(result.status).to eq("paid") }
    it { is_expected.to be_paid }
    it { expect(result.raw).to eq({}) }
  end

  RSpec.describe Providers::WebhookEvent do
    describe "#initialize" do
      context "with an unknown type" do
        it "raises ArgumentError" do
          expect { described_class.new(type: :bogus) }.to raise_error(ArgumentError)
        end
      end
    end

    describe "#payment_status" do
      it { expect(described_class.new(type: :payment_paid).payment_status).to eq("paid") }
      it { expect(described_class.new(type: :subscription_cancelled).payment_status).to be_nil }
    end

    describe "#ignored?" do
      it { expect(described_class.new(type: :ignored)).to be_ignored }
    end
  end
end
