require "rails_helper"

module ActiveBilling
  RSpec.describe Event, type: :model do
    subject(:event) { build(:active_billing_event, usage: usage, resource: nil) }

    let(:usage) { create(:active_billing_usage) }

    context "without a resource" do
      it { is_expected.to be_valid }
    end
  end
end
