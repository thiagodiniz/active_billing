require "rails_helper"

module ActiveBilling
  RSpec.describe Invoice, type: :model do
    subject(:invoice) { create(:active_billing_invoice, billing: billing, resource: store) }

    let(:store) { create(:store) }
    let(:billing) { create(:active_billing_billing, billable_entity: store) }
    let(:usage) { create(:active_billing_usage, billable_entity: store) }
    let(:other_usage) do
      create(:active_billing_usage, billable_entity: store, month: 1.month.ago.to_date.beginning_of_month)
    end

    describe "#valid?" do
      before do
        create(:active_billing_invoice_item, invoice: invoice, usage: usage)
        create(:active_billing_invoice_item, invoice: invoice, usage: other_usage)
        invoice.reload
      end

      it "does not delete items from the database" do
        invoice.add_usages_ids = [usage.id]
        expect { invoice.valid? }.not_to change(InvoiceItem, :count)
      end

      context "with a zero amount" do
        subject(:invoice) { build(:active_billing_invoice, billing: billing, amount_in_cents: 0) }

        it { is_expected.to be_valid }
      end
    end

    describe "#save" do
      before do
        create(:active_billing_invoice_item, invoice: invoice, usage: usage)
        create(:active_billing_invoice_item, invoice: invoice, usage: other_usage)
        invoice.reload
      end

      context "when a usage is removed" do
        it "destroys the item of the removed usage" do
          invoice.add_usages_ids = [usage.id]
          expect { invoice.save! }.to change(InvoiceItem, :count).by(-1)
        end

        it "keeps the item of the remaining usage" do
          invoice.add_usages_ids = [usage.id]
          invoice.save!
          expect(invoice.reload.usage_ids).to eq([usage.id])
        end
      end

      context "when the invoice is issued" do
        subject(:invoice) { create(:active_billing_invoice, :issued, billing: billing, resource: store) }

        it "rejects the change" do
          invoice.add_usages_ids = [usage.id]
          expect(invoice).not_to be_valid
        end

        it "does not destroy any item" do
          invoice.add_usages_ids = [usage.id]
          expect { invoice.save }.not_to change(InvoiceItem, :count)
        end
      end
    end

    describe "#set_description" do
      subject(:invoice) do
        build(:active_billing_invoice, billing: billing, description: nil, add_usages_ids: [usage.id])
      end

      before { create(:active_billing_event, usage: usage, resource: store) }

      it "generates a description from the usages" do
        invoice.valid?
        expect(invoice.description).to include(usage.uuid)
      end
    end

    describe "#add_usages_ids" do
      it "defaults to the current usages" do
        create(:active_billing_invoice_item, invoice: invoice, usage: usage)
        expect(invoice.reload.add_usages_ids).to eq([usage.id])
      end

      it "accepts an empty list" do
        invoice.add_usages_ids = []
        expect(invoice.add_usages_ids).to eq([])
      end
    end
  end
end
