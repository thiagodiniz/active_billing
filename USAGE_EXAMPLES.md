# ActiveBilling Usage Examples

Practical recipes for installing, configuring, and using ActiveBilling — both in embedded mode (host Rails app) and standalone mode (mounted billing service).

> **Implementation status.** Recipes that rely on the Billing lifecycle helpers (`close!`, `finalize!`, adjustment methods) and the standalone JSON API document the **intended** behavior and are tagged **(planned)** at the section level — those methods/endpoints are not yet implemented. The **Portal web UI**, **override generators**, Plan/Billing models, and `for_billable_entity` scoping work today.

## Table of Contents

1. [Basic Setup](#basic-setup)
2. [Plans](#plans)
3. [Billing Cycles](#billing-cycles)
4. [Recording Events](#recording-events)
5. [Closing and Adjusting](#closing-and-adjusting)
6. [Finalizing, Issuing, Charging](#finalizing-issuing-charging)
7. [Pricing Models](#pricing-models)
8. [Advanced Scenarios](#advanced-scenarios)
9. [Portal Web UI](#portal-web-ui)
10. [Standalone Mode (JSON API)](#standalone-mode-json-api)
11. [Testing](#testing)

## Basic Setup

### Configure ActiveBilling

```ruby
# config/initializers/active_billing.rb
ActiveBilling.configure do |config|
  config.currency               = :BRL
  config.default_cycle_interval = :monthly
  config.default_penalty        = 200  # 2.00% (basis points)
  config.default_interest       = 100  # 1.00%
  config.billing_entity_method  = :billing_entity

  # Default polymorphic type for the portal web UI when billable_entity_type
  # is not supplied as a query param.
  config.billable_entity_class  = "Customer"

  # Standalone mode only (planned — API not yet implemented)
  config.api_enabled    = false
  config.api_authorizer = ->(req) { ApiToken.find_by(token: req.headers["X-Api-Key"]) }
end
```

### Mark a billable entity

```ruby
class Customer < ApplicationRecord
  has_many :billings,
           as: :billable_entity,
           class_name: "ActiveBilling::Billing",
           dependent: :destroy

  has_many :usages,
           as: :billable_entity,
           class_name: "ActiveBilling::Usage",
           dependent: :destroy

  has_many :invoices,
           as: :resource,
           class_name: "ActiveBilling::Invoice",
           dependent: :destroy

  def billing_legal_name = company_name.presence || name
  def billing_tax_document = tax_id
end
```

## Plans

### Create a Plan

The shipped `Plan` model exposes `name`, `price_in_cents` (a money-typed attribute), `interval` (`monthly`/`yearly`), `allowances` (jsonb), and `active`. `price_in_cents` returns an `ActiveBilling::Money` value object:

```ruby
plan = ActiveBilling::Plan.create!(
  name: "Pro",
  price_in_cents: 9_900,                          # cents; or ActiveBilling::Money.from_amount(99.00)
  interval: "monthly",
  allowances: { api_call: 10_000, sms_sent: 200 },
  metadata: { tier: "pro" }
)

plan.price_in_cents          # => #<ActiveBilling::Money BRL 99.00>
plan.price_in_cents.to_d     # => 0.99e2 (BigDecimal)
plan.price_in_cents.cents    # => 9900
```

### Add domain logic to Plan

Add behavior in your app (e.g. via a decorator or a `to_prepare` reopen) using the money value object:

```ruby
# config/initializers/active_billing.rb (or a decorator)
Rails.application.config.to_prepare do
  ActiveBilling::Plan.class_eval do
    def annual_price
      price_in_cents.to_d * 12
    end
  end
end
```

## Billing Cycles

### Open a Billing for a customer

```ruby
billing = customer.billings.create!(
  plan:         ActiveBilling::Plan.find_by!(name: "Pro"),
  period_start: Date.current.beginning_of_month,
  period_end:   Date.current.end_of_month
)

ActiveBilling::Billing.current_for(customer)     # → the latest open Billing
```

While the Billing is `open`, assigning a `plan` snapshots it onto the record (`plan_name`, `plan_price_in_cents`, `plan_allowances`) on validation. A Billing can aggregate `Usage` records from multiple resources, so several stores can be unified into one Invoice/Charge or billed individually.

> **Planned:** automatically opening a `Usage` when a Billing is created is not yet implemented — associate `Usage` records with a Billing directly (`usage.update!(billing: billing)`).

### Custom interval

```ruby
customer.billings.create!(
  plan: plan,
  cycle_start: Date.current,
  cycle_end:   Date.current + 14.days,
  interval:    :custom
)
```

## Recording Events

### Single event

```ruby
billing.usage.events.create!(
  kind: "api_call",
  resource: api_request,
  metadata: { endpoint: api_request.endpoint, response_time_ms: api_request.duration },
  chargeable: true
)
```

### Batch insert (high throughput)

```ruby
rows = api_requests.map do |req|
  {
    billing_usage_id: billing.usage.id,
    kind: "api_call",
    metadata: { endpoint: req.endpoint },
    chargeable: true,
    created_at: Time.current,
    updated_at: Time.current
  }
end

ActiveBilling::Event.insert_all(rows)
```

### Subscription tracking

```ruby
billing.usage.events.create!(
  kind: "subscription_active",
  resource: subscription,
  metadata: { plan: subscription.plan_name, tier: subscription.tier }
)
```

## Closing and Adjusting

> **(Planned.)** This entire section describes the target lifecycle. `close!`, the adjustment helpers, and `BillingLineItem` are **not yet implemented**.

### Close the cycle

```ruby
billing.close!
# - Usage transitions to "closed" (no more events)
# - usage-derived line items are computed
# - plan recurring charge is added from the snapshot
# - Billing transitions to "closed" (still editable until finalized)
```

A scheduled job is the typical trigger:

```ruby
# app/jobs/billing/close_due_cycles_job.rb
class Billing::CloseDueCyclesJob < ApplicationJob
  queue_as :billing

  def perform
    ActiveBilling::Billing.due_for_close.find_each(&:close!)
  end
end
```

### Add manual line items

```ruby
billing.line_items.create!(
  key: "setup_fee",
  description: "One-time onboarding",
  quantity: 1,
  unit_price: 250.00
)
```

### Apply credits and discounts

```ruby
billing.apply_credit!(amount: 50.00, reason: "loyalty")
billing.apply_discount!(percent: 10, reason: "promo-may-2026")
billing.apply_discount!(amount: 25.00, reason: "manual goodwill")
```

### Combine multiple closed Usages into one Billing

```ruby
parent_account.billings.create!(plan: plan, cycle_start: …, cycle_end: …).tap do |b|
  parent_account.sub_accounts.each do |child|
    child_usage = child.usages.for_month(b.cycle_start).first
    b.add_usage!(child_usage) if child_usage&.closed?
  end
end
```

## Finalizing, Issuing, Charging

> **(Planned.)** `Billing#finalize!` and the `Charge` state-transition helpers are **not yet implemented**. You can still build `Invoice`/`InvoiceItem`/`Charge` records directly and associate them with a `Billing`.

```ruby
invoice = billing.finalize!     # creates Invoice + InvoiceItems; locks the Billing
invoice.issue!                  # state → issued; creates Charge in "created"

charge = invoice.charge
charge.mark_processing!
charge.mark_paid!(paid_at: Time.current)
# or
charge.mark_failed!(reason: "card_declined")
```

`Charge` callbacks are the integration point for payment providers (v1 ships state model only — see "Roadmap" in `CHANGELOG.md`):

```ruby
class Charge < ActiveBilling::Charge
  after_create :submit_to_gateway

  private

  def submit_to_gateway
    PaymentProvider.charge(self)
  end
end
```

## Pricing Models

### Per-event pricing

```ruby
class Billing < ActiveBilling::Billing
  def event_price_for(kind)
    case kind
    when "api_call" then 0.01
    when "sms_sent" then 0.05
    else 0.0
    end
  end
end
```

### Tiered (volume) pricing

```ruby
class Billing < ActiveBilling::Billing
  def event_price_for(kind)
    return super unless kind == "api_call"

    count = usage.events.api_call.chargeable.count
    if    count <= 1_000  then 0.010
    elsif count <= 10_000 then 0.008
    else                       0.005
    end
  end
end
```

### Plan with included allowances (free tier)

```ruby
class Billing < ActiveBilling::Billing
  def to_invoice_items_attributes
    api_calls   = usage.events.api_call.chargeable.count
    free_calls  = plan_allowances.fetch("api_call", 0)
    billable    = [api_calls - free_calls, 0].max

    items = super  # plan recurring + other items
    if billable.positive?
      items << {
        key: "api_call",
        description: "API calls (#{billable} billable, #{free_calls} included)",
        quantity: billable,
        unit_price: event_price_for("api_call")
      }
    end
    items
  end
end
```

### Minimum monthly charge

```ruby
class Billing < ActiveBilling::Billing
  MINIMUM_MONTHLY = 50.00

  def calculate_total
    [super, MINIMUM_MONTHLY].max
  end
end
```

## Advanced Scenarios

### Proration for mid-cycle plan changes

```ruby
class Billing < ActiveBilling::Billing
  def prorated_plan_amount(days_active)
    days_in_cycle = (cycle_end - cycle_start).to_i + 1
    (plan_amount / days_in_cycle) * days_active
  end
end
```

### Credits ledger

```ruby
# app/models/credit.rb
class Credit < ApplicationRecord
  belongs_to :customer
  belongs_to :billing, class_name: "ActiveBilling::Billing", optional: true

  scope :available, -> { where(consumed_at: nil) }
end

class Billing < ActiveBilling::Billing
  before_finalize :apply_available_credits

  private

  def apply_available_credits
    billable_entity.credits.available.find_each do |credit|
      apply_credit!(amount: credit.amount, reason: "credit_##{credit.id}")
      credit.update!(consumed_at: Time.current, billing: self)
    end
  end
end
```

### Multi-currency

```ruby
class Customer < ApplicationRecord
  enum :currency, { brl: "BRL", usd: "USD", eur: "EUR" }
end

class Billing < ActiveBilling::Billing
  before_validation :inherit_currency_from_entity

  private

  def inherit_currency_from_entity
    self.currency ||= billable_entity.currency
  end
end
```

### Usage reporting

```ruby
module Billing
  class UsageReport
    def initialize(customer, range)
      @customer = customer
      @range = range
    end

    def call
      billings = @customer.billings.where(cycle_start: @range).includes(usage: :events, invoice: :items)

      {
        customer: @customer.billing_legal_name,
        range: @range,
        total_events:  billings.sum { |b| b.usage&.events&.count.to_i },
        total_billed:  billings.sum { |b| b.invoice&.amount.to_f },
        per_cycle: billings.map { |b| cycle_summary(b) }
      }
    end

    private

    def cycle_summary(b)
      {
        cycle: "#{b.cycle_start} – #{b.cycle_end}",
        plan: b.plan_name,
        events: b.usage&.events&.count.to_i,
        invoice_state: b.invoice&.state,
        total: b.invoice&.amount
      }
    end
  end
end
```

## Portal Web UI

Mount the engine to expose the read-only portal. Every list is scoped by `billable_entity_id` (and `billable_entity_type`, unless `config.billable_entity_class` is set):

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount ActiveBilling::Engine => "/billing"
end
```

```
GET /billing/invoices?billable_entity_id=42&billable_entity_type=Store   # list
GET /billing/invoices/123?billable_entity_id=42&billable_entity_type=Store
GET /billing/usages?billable_entity_id=42&billable_entity_type=Store
GET /billing/charges?billable_entity_id=42&billable_entity_type=Store
GET /billing/plan?billable_entity_id=42&billable_entity_type=Store       # current plan
```

`index` actions return **400** when no `billable_entity_id` (or resolvable type) is supplied. The portal is read-only — there are no create/update/destroy routes.

### Override the shipped views or controllers

The engine's views/controllers are used by default. Generate local copies to customize them; Rails resolves the host app's files ahead of the engine's:

```bash
bin/rails generate active_billing:views        # → app/views/active_billing/**
bin/rails generate active_billing:controllers  # → app/controllers/active_billing/**
bin/rails generate active_billing:install      # → config/initializers/active_billing.rb
```

For example, after `active_billing:views` you can edit `app/views/active_billing/invoices/index.html.erb` to change how invoices render, without touching the gem.

## Standalone Mode (JSON API)

> **(Planned.)** The JSON API below is **not yet implemented**. Mounting the engine today gives you the read-only [Portal Web UI](#portal-web-ui); the versioned API controllers and serializers are on the roadmap.

When the gem runs as a standalone billing service, external products interact over HTTP. Mount the engine and enable the API:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount ActiveBilling::Engine => "/billing"
end

# config/initializers/active_billing.rb
ActiveBilling.configure do |config|
  config.api_enabled    = true
  config.api_authorizer = ->(request) {
    ApiToken.find_by(token: request.headers["X-Api-Key"])
  }
end
```

### Create a Billing

```http
POST /billing/api/v1/billings
X-Api-Key: <token>
Content-Type: application/json

{
  "billable_entity": { "type": "Customer", "id": "cus_123" },
  "plan_id":     "plan_pro",
  "cycle_start": "2026-05-01",
  "cycle_end":   "2026-05-31",
  "interval":    "monthly"
}
```

### Append an event

```http
POST /billing/api/v1/billings/:id/events
X-Api-Key: <token>
Content-Type: application/json

{ "kind": "api_call", "metadata": { "endpoint": "/v1/users" }, "chargeable": true }
```

### Lifecycle commands

```http
POST /billing/api/v1/billings/:id/close
POST /billing/api/v1/billings/:id/line_items   (adjustments)
POST /billing/api/v1/billings/:id/credits
POST /billing/api/v1/billings/:id/discounts
POST /billing/api/v1/billings/:id/finalize
GET  /billing/api/v1/invoices/:id
POST /billing/api/v1/invoices/:id/issue
POST /billing/api/v1/charges/:id/mark_paid
```

Every endpoint maps 1:1 to a model method in embedded mode. The standalone API is a thin HTTP surface — no parallel business logic.

## Testing

> **Note.** The lifecycle and standalone-API specs below exercise **planned** behavior (`close!`, `finalize!`, the JSON API) and reference factory/attribute names from the target design. The specs that ship today live under `spec/` — model specs for `Plan`/`Billing` and the `for_billable_entity` scopes, plus request/routing specs for the portal — and use factories like `:active_billing_plan`, `:active_billing_billing`, etc. Run them with `bundle exec rspec` (PostgreSQL required).

### Plan spec

```ruby
RSpec.describe ActiveBilling::Plan do
  subject(:plan) { build(:plan) }

  it { is_expected.to be_valid }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_numericality_of(:recurring_amount_in_cents).is_greater_than(0) }
end
```

### Billing lifecycle spec

```ruby
RSpec.describe ActiveBilling::Billing do
  subject(:billing) { create(:billing, plan: plan) }
  let(:plan) { create(:plan, recurring_amount: 99.00) }

  describe "#close!" do
    context "when usage has events" do
      before { create_list(:event, 3, usage: billing.usage, kind: "api_call") }

      it "transitions the usage to closed" do
        expect { billing.close! }.to change { billing.usage.reload.state }.from("open").to("closed")
      end

      it "adds the plan recurring charge as a line item" do
        expect { billing.close! }.to change { billing.line_items.where(key: "plan").count }.by(1)
      end
    end
  end

  describe "#finalize!" do
    context "when billing is closed" do
      before { billing.close! }

      it "produces an Invoice" do
        expect { billing.finalize! }.to change(ActiveBilling::Invoice, :count).by(1)
      end
    end

    context "when billing is still open" do
      it "raises a validation error" do
        expect { billing.finalize! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
```

### Adjustments spec

```ruby
RSpec.describe ActiveBilling::Billing do
  subject(:billing) { create(:billing, :closed) }

  describe "#apply_credit!" do
    it "creates a credit line item" do
      expect { billing.apply_credit!(amount: 25.00, reason: "loyalty") }
        .to change { billing.line_items.credits.count }.by(1)
    end
  end

  describe "#apply_discount!" do
    context "with percent" do
      it "stores the percentage and reason" do
        billing.apply_discount!(percent: 10, reason: "promo")
        expect(billing.line_items.discounts.last).to have_attributes(percent: 10, reason: "promo")
      end
    end
  end
end
```

### Standalone API request spec

```ruby
RSpec.describe "POST /billing/api/v1/billings", type: :request do
  let(:token) { create(:api_token) }
  let(:plan)  { create(:plan) }

  context "with a valid token" do
    it "creates a billing" do
      post "/billing/api/v1/billings",
           params: { plan_id: plan.id, cycle_start: "2026-05-01", cycle_end: "2026-05-31", interval: "monthly" }.to_json,
           headers: { "X-Api-Key" => token.token, "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
    end
  end

  context "without a token" do
    it "returns 401" do
      post "/billing/api/v1/billings"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

## Additional resources

- [README](README.md) — install + concepts
- [ARCHITECTURE](ARCHITECTURE.md) — data model + flows
- [STRUCTURE](STRUCTURE.md) — directory layout
- [CLAUDE.md](CLAUDE.md) — code style + RSpec conventions
