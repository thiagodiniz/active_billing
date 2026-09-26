require "rails_helper"

module ActiveBilling
  RSpec.describe "for_billable_entity scopes", type: :model do
    let(:store) { create(:store) }
    let(:other) { create(:store) }
    let(:billing) { create(:active_billing_billing, billable_entity: store) }

    describe "Usage.for_billable_entity" do
      it "returns usages for the given entity only" do
        mine = create(:active_billing_usage, billable_entity: store)
        create(:active_billing_usage, billable_entity: other)
        expect(Usage.for_billable_entity("Store", store.id)).to eq([mine])
      end
    end

    describe "Invoice.for_billable_entity" do
      it "returns invoices whose billing belongs to the entity" do
        mine = create(:active_billing_invoice, billing: billing)
        create(:active_billing_invoice, billing: create(:active_billing_billing, billable_entity: other))
        expect(Invoice.for_billable_entity("Store", store.id)).to eq([mine])
      end

      context "when the invoice has no billing" do
        it "matches by resource" do
          mine = create(:active_billing_invoice, billing: nil, resource: store)
          create(:active_billing_invoice, billing: nil, resource: other)
          expect(Invoice.for_billable_entity("Store", store.id)).to eq([mine])
        end

        it "ignores the resource when the billing belongs to another entity" do
          create(:active_billing_invoice, resource: store,
                                          billing: create(:active_billing_billing, billable_entity: other))
          expect(Invoice.for_billable_entity("Store", store.id)).to be_empty
        end
      end
    end

    describe "Charge.for_billable_entity" do
      it "returns charges whose invoice billing belongs to the entity" do
        mine = create(:active_billing_charge, invoice: create(:active_billing_invoice, billing: billing))
        create(:active_billing_charge)
        expect(Charge.for_billable_entity("Store", store.id)).to eq([mine])
      end
    end
  end
end
