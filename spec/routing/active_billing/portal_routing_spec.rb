require "rails_helper"

RSpec.describe "ActiveBilling portal routing", type: :routing do
  routes { ActiveBilling::Engine.routes }

  it "routes GET /invoices to the index" do
    expect(get: "/invoices").to route_to("active_billing/invoices#index")
  end

  it "routes GET /invoices/1 to show" do
    expect(get: "/invoices/1").to route_to("active_billing/invoices#show", id: "1")
  end

  it "routes GET /plan to the plan show" do
    expect(get: "/plan").to route_to("active_billing/plans#show")
  end

  it "does not route POST /invoices (no create)" do
    expect(post: "/invoices").not_to be_routable
  end

  it "does not route GET /invoices/1/edit (no edit)" do
    expect(get: "/invoices/1/edit").not_to be_routable
  end

  it "does not route DELETE /charges/1 (no destroy)" do
    expect(delete: "/charges/1").not_to be_routable
  end
end
