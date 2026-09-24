require "rails_helper"

module ActiveBilling
  RSpec.describe Charge, type: :model do
    subject(:charge) { create(:active_billing_charge) }

    it { is_expected.to be_created }
    it { is_expected.not_to be_finished }
    it { is_expected.not_to be_synced }

    describe "#apply_provider_result!" do
      let(:result) { Providers::Result.new(external_id: "pay_1", status: "processing", url: "https://pay", raw: { "a" => 1 }) }

      before { charge.apply_provider_result!(:test, result) }

      it { expect(charge).to have_attributes(provider: "test", external_id: "pay_1", payment_url: "https://pay") }
      it { expect(charge).to be_processing }
      it { expect(charge.metadata).to eq("a" => 1) }
    end

    describe "#apply_webhook_event!" do
      let(:occurred_at) { Time.zone.parse("2026-01-02 03:04:05") }

      context "with a payment_paid event" do
        before { charge.apply_webhook_event!(Providers::WebhookEvent.new(type: :payment_paid, occurred_at: occurred_at)) }

        it { expect(charge).to be_paid }
        it { expect(charge.paid_at).to eq(occurred_at) }
      end

      context "with a payment_failed event" do
        before { charge.apply_webhook_event!(Providers::WebhookEvent.new(type: :payment_failed)) }

        it { expect(charge).to be_failed }
        it { expect(charge.failed_at).to be_present }
      end

      context "with a subscription event" do
        it "does not change the state" do
          expect { charge.apply_webhook_event!(Providers::WebhookEvent.new(type: :subscription_updated)) }
            .not_to change(charge, :state)
        end
      end
    end

    describe ".lookup" do
      subject(:charge) { create(:active_billing_charge, :synced) }

      it { expect(described_class.lookup(:test, charge.external_id)).to eq(charge) }
    end
  end
end
