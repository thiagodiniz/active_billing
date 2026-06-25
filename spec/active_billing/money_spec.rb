require "rails_helper"

module ActiveBilling
  RSpec.describe Money do
    describe ".from_amount" do
      it "converts major units to cents" do
        expect(Money.from_amount(99.99).cents).to eq(9_999)
      end
    end

    describe ".from_cents" do
      it "stores the integer cents" do
        expect(Money.from_cents(2_500).cents).to eq(2_500)
      end
    end

    describe "#to_d" do
      it "returns an exact decimal" do
        expect(Money.from_cents(2_500).to_d).to eq(BigDecimal("25"))
      end
    end

    describe "#as_json" do
      it "serializes to integer cents" do
        expect(Money.from_cents(2_500).as_json).to eq(2_500)
      end
    end

    describe "#zero?" do
      it { expect(Money.from_cents(0)).to be_zero }
    end

    describe "comparison" do
      it { expect(Money.from_cents(100)).to be > Money.from_cents(50) }
    end

    describe "#+" do
      it "adds two amounts" do
        expect((Money.from_cents(100) + Money.from_cents(50)).cents).to eq(150)
      end
    end
  end

  RSpec.describe Type::Money, type: :model do
    subject(:plan) { create(:active_billing_plan, price_in_cents: 1_234) }

    it "casts an assigned integer to Money" do
      expect(build(:active_billing_plan, price_in_cents: 500).price_in_cents).to eq(Money.from_cents(500))
    end

    it "round-trips through the database as Money" do
      expect(plan.reload.price_in_cents).to eq(Money.from_cents(1_234))
    end

    it "serializes Money back to integer cents for the database" do
      type = Plan.type_for_attribute("price_in_cents")
      expect(type.serialize(Money.from_cents(1_234))).to eq(1_234)
    end
  end
end
