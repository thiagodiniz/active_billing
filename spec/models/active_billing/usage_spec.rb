require "rails_helper"

module ActiveBilling
  RSpec.describe Usage, type: :model do
    subject(:usage) { create(:active_billing_usage, billable_entity: store) }

    let(:store) { create(:store) }

    describe "#billable_entity" do
      it { expect(usage.billable_entity).to eq(store) }
    end

    describe "#to_invoice_items_attributes" do
      before { create_list(:active_billing_event, 2, usage: usage, resource: store, kind: "api_call") }

      it "groups chargeable events by kind" do
        expect(usage.to_invoice_items_attributes)
          .to eq([{ key: "api_call", quantity: 2, unit_price: 0.0, usage_id: usage.id }])
      end
    end
  end
end
