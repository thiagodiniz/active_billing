require "rails_helper"

module ActiveBilling
  RSpec.describe "for_billable_entity scopes", type: :model do
    let(:store) { create(:store) }
    let(:other) { create(:store) }
    let(:subscription) { create(:active_billing_subscription, billable_entity: store) }

    describe "Usage.for_billable_entity" do
      it "returns usages for the given entity only" do
        mine = create(:active_billing_usage, billable_entity: store)
        create(:active_billing_usage, billable_entity: other)
        expect(Usage.for_billable_entity("Store", store.id)).to eq([mine])
      end
    end

    describe "Invoice.for_billable_entity" do
      it "returns invoices whose subscription belongs to the entity" do
        mine = create(:active_billing_invoice, subscription: subscription)
        create(:active_billing_invoice, subscription: create(:active_billing_subscription, billable_entity: other))
        expect(Invoice.for_billable_entity("Store", store.id)).to eq([mine])
      end

      context "when the invoice has no subscription" do
        it "matches by resource" do
          mine = create(:active_billing_invoice, subscription: nil, resource: store)
          create(:active_billing_invoice, subscription: nil, resource: other)
          expect(Invoice.for_billable_entity("Store", store.id)).to eq([mine])
        end

        it "ignores the resource when the subscription belongs to another entity" do
          create(:active_billing_invoice, resource: store,
                                          subscription: create(:active_billing_subscription, billable_entity: other))
          expect(Invoice.for_billable_entity("Store", store.id)).to be_empty
        end
      end
    end

    describe "Charge.for_billable_entity" do
      it "returns charges whose invoice subscription belongs to the entity" do
        mine = create(:active_billing_charge, invoice: create(:active_billing_invoice, subscription: subscription))
        create(:active_billing_charge)
        expect(Charge.for_billable_entity("Store", store.id)).to eq([mine])
      end
    end
  end
end
