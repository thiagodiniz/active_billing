require "rails_helper"

module ActiveBilling
  RSpec.describe Billing, type: :model do
    subject(:billing) { build(:active_billing_billing, billable_entity: store) }

    let(:store) { create(:store) }

    it { is_expected.to be_valid }

    describe "plan snapshot" do
      let(:plan) { create(:active_billing_plan, name: "Pro", price_in_cents: 9_900, allowances: { "seats" => 5 }) }

      subject(:billing) { build(:active_billing_billing, billable_entity: store, plan: plan) }

      context "when the billing is open" do
        it "snapshots the plan name on validation" do
          billing.valid?
          expect(billing.plan_name).to eq("Pro")
        end

        it "snapshots the plan price on validation" do
          billing.valid?
          expect(billing.plan_price_in_cents).to eq(9_900)
        end
      end
    end

    describe ".current_for" do
      context "when an open billing exists" do
        it "returns the most recent open billing" do
          current = create(:active_billing_billing, billable_entity: store)
          expect(Billing.current_for(store)).to eq(current)
        end
      end

      context "when only a finalized billing exists" do
        before { create(:active_billing_billing, :finalized, billable_entity: store) }

        it { expect(Billing.current_for(store)).to be_nil }
      end

      context "when the entity is nil" do
        it { expect(Billing.current_for(nil)).to be_nil }
      end
    end

    describe ".for_billable_entity" do
      it "scopes by polymorphic type and id" do
        mine = create(:active_billing_billing, billable_entity: store)
        create(:active_billing_billing, billable_entity: create(:store))
        expect(Billing.for_billable_entity("Store", store.id)).to eq([mine])
      end
    end
  end
end
