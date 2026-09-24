require "rails_helper"

module ActiveBilling
  RSpec.describe ProviderAccount, :providers, type: :model do
    subject(:account) { build(:active_billing_provider_account, billable_entity: store) }

    let(:store) { create(:store) }

    it { is_expected.to be_valid }

    context "with an unregistered provider" do
      subject(:account) { build(:active_billing_provider_account, provider: "nope") }

      it { is_expected.not_to be_valid }
    end

    context "when the entity already has an account on the provider" do
      before { create(:active_billing_provider_account, billable_entity: store) }

      it { is_expected.not_to be_valid }
    end

    describe ".current_for" do
      it { expect(described_class.current_for(nil)).to be_nil }

      it "returns the active account" do
        account.save!
        expect(described_class.current_for(store)).to eq(account)
      end
    end

    describe "#adapter" do
      it { expect(account.adapter).to be_a(Providers::Test) }
    end

    describe "#synced?" do
      it { is_expected.not_to be_synced }

      context "with an external customer id" do
        subject(:account) { build(:active_billing_provider_account, :synced) }

        it { is_expected.to be_synced }
      end
    end
  end

  RSpec.describe ProviderReference, type: :model do
    subject(:reference) { build(:active_billing_provider_reference) }

    it { is_expected.to be_valid }

    describe ".upsert_from" do
      let(:plan) { create(:active_billing_plan) }
      let(:result) { Providers::Result.new(external_id: "plan_x", raw: { "price" => 1 }) }

      it "creates the reference" do
        expect { described_class.upsert_from(plan, :test, result) }.to change(described_class, :count).by(1)
      end

      it "updates the existing reference" do
        described_class.upsert_from(plan, :test, result)
        updated = described_class.upsert_from(plan, :test, Providers::Result.new(external_id: "plan_y"))
        expect(updated).to have_attributes(external_id: "plan_y", metadata: { "price" => 1 })
      end
    end

    describe ".lookup" do
      it "finds by provider and external id" do
        reference.save!
        expect(described_class.lookup("test", reference.external_id)).to eq(reference)
      end
    end
  end
end
