require "rails_helper"

module ActiveBilling
  RSpec.describe Providers::Synchronizer, :providers do
    let(:store) { create(:store) }
    let(:calls) { Providers::Test.calls.map(&:first) }

    describe "#perform" do
      it "rejects unknown operations" do
        expect { described_class.perform(store, :explode) }.to raise_error(ArgumentError)
      end
    end

    describe "customers" do
      subject(:account) { create(:active_billing_provider_account, billable_entity: store) }

      it "creates the remote customer on account creation" do
        expect(account.reload.external_customer_id).to start_with("customer_")
      end

      it "does not recreate an already synced customer" do
        described_class.perform(account, :create_customer)
        expect(calls.count(:create_customer)).to eq(1)
      end

      it "updates the remote customer when the account changes" do
        account.update!(metadata: { "vat" => "1" })
        expect(calls.last).to eq(:update_customer)
      end
    end

    describe "plans" do
      subject(:plan) { create(:active_billing_plan) }

      it "mirrors the plan to every configured provider" do
        expect(plan.provider_ids.keys).to eq(%w[test])
      end

      it "makes the first provider the current one" do
        expect(plan).to have_attributes(provider: "test", provider_id: plan.provider_ids.dig("test", "id"))
      end

      it "updates the remote plan when priced attributes change" do
        plan.update!(price_in_cents: 2_000)
        expect(calls.last).to eq(:update_plan)
      end

      it "skips the sync when nothing relevant changes" do
        plan.update!(updated_at: 1.minute.from_now)
        expect(calls).to eq([:create_plan])
      end

      it "archives on every provider holding a reference" do
        described_class.perform(plan, :archive_plan)
        expect(calls.last).to eq(:archive_plan)
      end
    end

    describe "subscriptions" do
      let(:plan) { create(:active_billing_plan) }

      subject(:subscription) { create(:active_billing_subscription, billable_entity: store, plan: plan) }

      context "when the entity has no provider account" do
        it "does nothing" do
          subscription
          expect(calls).not_to include(:create_subscription)
        end

        context "with a default provider" do
          before { ActiveBilling.configuration.default_provider = :test }

          it "creates the account and the remote subscription" do
            expect(subscription.provider_reference_for(:test)).to be_present
            expect(ProviderAccount.current_for(store)).to be_synced
          end
        end
      end

      context "when the entity has a provider account" do
        before { create(:active_billing_provider_account, billable_entity: store) }

        it "creates the remote subscription" do
          expect(subscription.provider_reference_for(:test)).to be_present
        end

        it "passes the customer and plan references" do
          subscription
          record = Providers::Test.store[:subscriptions].values.first
          expect(record).to include(customer_id: a_string_starting_with("customer_"),
                                    plan_id: plan.provider_reference_for(:test).external_id)
        end

        it "cancels the remote subscription when finalized" do
          subscription.update!(state: "finalized")
          expect(calls.last).to eq(:cancel_subscription)
        end

        it "updates the remote subscription when the period changes" do
          subscription.update!(period_end: Date.current)
          expect(calls.last).to eq(:update_subscription)
        end

        it "does not recreate an already synced subscription" do
          subscription
          described_class.perform(subscription, :create_subscription)
          expect(calls.count(:create_subscription)).to eq(1)
        end
      end

      context "when the account has never been synced" do
        before { create(:active_billing_provider_account, billable_entity: store, skip_provider_sync: true) }

        it "creates the customer first" do
          subscription
          expect(calls).to include(:create_customer, :create_subscription)
        end
      end
    end

    describe "payments" do
      let(:invoice) do
        create(:active_billing_invoice, resource: store,
                                        subscription: create(:active_billing_subscription, billable_entity: store))
      end

      subject(:charge) { create(:active_billing_charge, resource: store, invoice: invoice) }

      context "without a provider account" do
        it { expect(charge.reload).not_to be_synced }
      end

      context "with a provider account" do
        before { create(:active_billing_provider_account, billable_entity: store) }

        it "creates the payment on the provider" do
          expect(charge.reload).to have_attributes(provider: "test", state: "pending")
        end

        it "stores the hosted payment url" do
          expect(charge.reload.payment_url).to eq("https://pay.test/#{charge.uuid}")
        end

        it "refreshes the state from the provider" do
          Providers::Test.store[:payments][charge.reload.external_id][:status] = "paid"
          charge.refresh_from_provider!
          expect(charge).to be_paid
        end

        it "cancels the payment on the provider" do
          described_class.perform(charge, :cancel_payment)
          expect(charge).to be_cancelled
        end
      end
    end
  end
end
