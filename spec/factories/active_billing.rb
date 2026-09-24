FactoryBot.define do
  factory :active_billing_plan, class: "ActiveBilling::Plan" do
    sequence(:name) { |n| "Plan ##{n}" }
    price_in_cents { 1_000 }
    interval { "monthly" }
    allowances { { "api_calls" => 1_000 } }
    active { true }
  end

  factory :active_billing_billing, class: "ActiveBilling::Billing" do
    association :billable_entity, factory: :store
    association :plan, factory: :active_billing_plan
    state { "open" }

    trait :finalized do
      state { "finalized" }
    end

    trait :without_plan do
      plan { nil }
    end
  end

  factory :active_billing_usage, class: "ActiveBilling::Usage" do
    association :billable_entity, factory: :store
    month { Date.current.beginning_of_month }
    total_cost_in_cents { 0 }
  end

  factory :active_billing_event, class: "ActiveBilling::Event" do
    association :usage, factory: :active_billing_usage
    association :resource, factory: :store
    kind { "api_call" }
  end

  factory :active_billing_invoice, class: "ActiveBilling::Invoice" do
    association :resource, factory: :store
    association :billing, factory: :active_billing_billing
    state { "created" }
    amount_in_cents { 5_000 }
    description { "Test invoice" }

    trait :issued do
      state { "issued" }
      issued_at { Date.current }
    end
  end

  factory :active_billing_invoice_item, class: "ActiveBilling::InvoiceItem" do
    association :invoice, factory: :active_billing_invoice
    key { "api_calls" }
    quantity { 10 }
    unit_price { 1.50 }
  end

  factory :active_billing_charge, class: "ActiveBilling::Charge" do
    association :resource, factory: :store
    association :invoice, factory: :active_billing_invoice

    trait :synced do
      provider { "test" }
      sequence(:external_id) { |n| "payment_#{n}" }
      state { "pending" }
    end
  end

  factory :active_billing_provider_account, class: "ActiveBilling::ProviderAccount" do
    association :billable_entity, factory: :store
    provider { "test" }
    active { true }

    trait :synced do
      sequence(:external_customer_id) { |n| "customer_#{n}" }
    end
  end

  factory :active_billing_provider_reference, class: "ActiveBilling::ProviderReference" do
    association :record, factory: :active_billing_plan
    provider { "test" }
    sequence(:external_id) { |n| "plan_#{n}" }
  end
end
