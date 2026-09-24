require "rails_helper"

module ActiveBilling
  RSpec.describe Providers::WebhookProcessor, :providers do
    subject(:processor) { described_class.new(:test) }

    let(:headers) { { "X-Test-Signature" => "whsec_test" } }

    describe "#call" do
      context "with an invalid signature" do
        it "raises InvalidWebhookSignature" do
          expect { processor.call({ type: "payment_paid" }.to_json, {}) }
            .to raise_error(Providers::InvalidWebhookSignature)
        end
      end

      context "with a payment event" do
        let(:charge) { create(:active_billing_charge, :synced) }
        let(:payload) { { type: "payment_paid", id: charge.external_id }.to_json }

        it "marks the charge as paid" do
          processor.call(payload, headers)
          expect(charge.reload).to be_paid
        end

        it "records paid_at" do
          processor.call(payload, headers)
          expect(charge.reload.paid_at).to be_present
        end

        it "does not reopen a finished charge" do
          charge.update!(state: "failed")
          processor.call(payload, headers)
          expect(charge.reload).to be_failed
        end
      end

      context "with a payment event for an unknown charge" do
        it "ignores it" do
          expect(processor.call({ type: "payment_paid", id: "nope" }.to_json, headers).type).to eq(:payment_paid)
        end
      end

      context "with a subscription event" do
        let(:billing) { create(:active_billing_billing) }
        let(:reference) { create(:active_billing_provider_reference, record: billing, external_id: "sub_1") }
        let(:payload) { { type: "subscription_cancelled", id: reference.external_id }.to_json }

        it "records the status on the reference" do
          processor.call(payload, headers)
          expect(reference.reload.metadata["status"]).to eq("cancelled")
        end
      end

      context "with an ignored event" do
        it "returns the event untouched" do
          expect(processor.call({ type: "ignored" }.to_json, headers)).to be_ignored
        end
      end
    end
  end
end
