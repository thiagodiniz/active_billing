require "rails_helper"

module ActiveBilling
  RSpec.describe Plan, type: :model do
    subject(:plan) { build(:active_billing_plan) }

    it { is_expected.to be_valid }

    it "is an ActiveRecord model" do
      expect(Plan.ancestors).to include(ActiveRecord::Base)
    end

    describe "validations" do
      context "without a name" do
        before { plan.name = nil }

        it { is_expected.not_to be_valid }
      end

      context "with a negative price" do
        before { plan.price_in_cents = -1 }

        it { is_expected.not_to be_valid }
      end
    end

    describe "#price_in_cents" do
      before { plan.price_in_cents = 2_500 }

      it "returns a Money value object" do
        expect(plan.price_in_cents).to be_a(ActiveBilling::Money)
      end

      it "exposes an exact decimal amount" do
        expect(plan.price_in_cents.to_d).to eq(BigDecimal("25"))
      end
    end

    describe ".active" do
      it "returns only active plans" do
        active = create(:active_billing_plan, active: true)
        create(:active_billing_plan, active: false)
        expect(Plan.active).to eq([active])
      end
    end
  end
end
