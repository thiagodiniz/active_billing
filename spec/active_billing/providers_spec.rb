require "rails_helper"

module ActiveBilling
  RSpec.describe Providers, :providers do
    let(:store) { create(:store) }

    describe ".register" do
      let(:adapter_class) { Class.new(Providers::Base) }

      after { Providers.unregister(:custom) }

      it "makes the adapter resolvable by name" do
        Providers.register(:custom, adapter_class)
        expect(Providers.fetch("custom")).to eq(adapter_class)
      end
    end

    describe ".fetch" do
      context "with an unknown name" do
        it "raises UnknownProvider" do
          expect { Providers.fetch(:nope) }.to raise_error(Providers::UnknownProvider)
        end
      end
    end

    describe ".build" do
      subject(:adapter) { Providers.build(:test) }

      it { is_expected.to be_a(Providers::Test) }

      it "passes the configured settings" do
        expect(adapter.setting(:webhook_secret)).to eq("whsec_test")
      end
    end

    describe ".configured_names" do
      it "lists registered providers with settings" do
        ActiveBilling.configuration.providers[:missing] = {}
        expect(Providers.configured_names).to eq([:test])
      end
    end

    describe ".name_for" do
      subject(:name) { Providers.name_for(store) }

      context "without account, resolver or default" do
        it { is_expected.to be_nil }
      end

      context "with a default provider" do
        before { ActiveBilling.configuration.default_provider = :test }

        it { is_expected.to eq(:test) }
      end

      context "with a resolver" do
        before do
          ActiveBilling.configuration.default_provider = :other
          ActiveBilling.configuration.provider_resolver = ->(entity) { :test if entity.is_a?(Store) }
        end

        it { is_expected.to eq(:test) }
      end

      context "with an active provider account" do
        before do
          ActiveBilling.configuration.provider_resolver = ->(_entity) { :other }
          create(:active_billing_provider_account, billable_entity: store, provider: "test")
        end

        it { is_expected.to eq(:test) }
      end

      context "with only an inactive provider account" do
        before { create(:active_billing_provider_account, billable_entity: store, active: false) }

        it { is_expected.to be_nil }
      end
    end

    describe ".for" do
      context "when no provider can be resolved" do
        it "raises UnknownProvider" do
          expect { Providers.for(store) }.to raise_error(Providers::UnknownProvider)
        end
      end

      context "when the entity has an account" do
        before { create(:active_billing_provider_account, billable_entity: store) }

        it { expect(Providers.for(store)).to be_a(Providers::Test) }
      end
    end
  end
end
