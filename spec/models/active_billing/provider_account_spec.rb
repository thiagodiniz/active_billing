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

    context "when the entity already has an account" do
      before { create(:active_billing_provider_account, billable_entity: store) }

      it { is_expected.not_to be_valid }
    end

    describe ".current_for" do
      it { expect(described_class.current_for(nil)).to be_nil }

      it "returns the entity's account" do
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
end
