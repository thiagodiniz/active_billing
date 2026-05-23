# ActiveBilling

A Rails-focused Ruby gem for SaaS billing. ActiveBilling manages billing cycles, tracks plan-based and usage-based consumption, closes cycles, generates invoices, and records payment. It runs **embedded** inside an existing Rails application (models, controllers, jobs, helpers) or **standalone** as a thin billing service that receives input from external apps over a JSON API.

## Core concepts

The central concept is a **Billing**. A `Billing` record represents one configured billing cycle for a billable entity (a customer, organization, tenant — anything in your app you want to bill). It carries:

- the cycle window (start, end, interval — monthly, weekly, or a custom interval)
- a snapshot of the **Plan** attached to the cycle (fixed recurring price + included allowances)
- references to the **Usage** records measured during the cycle
- additional line items, credits, and discounts added before finalization

When the cycle ends, the gem **closes** the underlying Usage, **finalizes** the Billing, **generates** the Invoice, and **records or initiates** the payment via Charge.

```
Billable Entity (Customer / Organization / Tenant)
   │
   │ has_many
   ▼
Billing (cycle config + plan snapshot + adjustments)
   │
   ├── Usage (closed measurement of events in the cycle)
   │      └── Event (individual billable action)
   │
   ├── adjustments: extra line items, credits, discounts
   │
   ▼ finalize
Invoice ── has_many ──► InvoiceItem
   │
   ▼
Charge (payment state machine)
```

| Model         | Responsibility                                                                  | Mutable? |
| ------------- | ------------------------------------------------------------------------------- | -------- |
| `Plan`        | Catalog entry: recurring price, included allowances, metadata                   | Yes (catalog edits do not affect past Billings — they snapshot) |
| `Billing`     | One configured billing cycle for a billable entity; aggregates Usages + plan + adjustments | Yes until finalized |
| `Usage`       | Per-period measurement bucket for one billable entity                           | Yes while open; **closed** at cycle end then immutable |
| `Event`       | A single billable action recorded against a Usage (API call, SMS, storage, etc.) | Append-only |
| `Invoice`     | Document generated from a finalized Billing                                     | State-machine; immutable items after issued |
| `InvoiceItem` | Line item on an invoice                                                         | Owned by Invoice |
| `Charge`      | Payment record + state machine (created → processing → paid / failed / expired) | State-machine |

### Lifecycle

```
1. Configure cycle      ── create Billing with cycle window + Plan snapshot
2. Record consumption   ── append Events to the open Usage(s) for this entity
3. Close cycle          ── Usage transitions to "closed" (no more events)
4. Adjust Billing       ── add/edit line items, apply credits and discounts
5. Finalize Billing     ── locks adjustments; generates Invoice + InvoiceItems
6. Issue Invoice        ── invoice moves to "issued"; Charge is created
7. Collect payment      ── Charge transitions through processing → paid/failed
```

## Two install modes

### Embedded mode

ActiveBilling installs as a Rails engine inside your app. Your Rails code talks to `ActiveBilling::Billing`, `ActiveBilling::Usage`, etc. directly — same models, jobs, helpers as anything else in the app.

Use this when billing is part of the same Rails monolith as the product.

### Standalone mode

The same gem can be `mount`ed inside a thin Rails app to run as a separate billing service. External applications push events and issue billing commands over a JSON API (token-authenticated). The gem ships the engine, routes, controllers, and serializers; the host app supplies auth tokens and any persistence configuration.

Use this when multiple products share one billing service, or when billing needs to run in its own deployable.

```ruby
# config/routes.rb in a standalone billing service
Rails.application.routes.draw do
  mount ActiveBilling::Engine => "/billing"
end
```

Both modes use the same models and the same lifecycle — standalone mode is the embedded engine + an HTTP surface.

## Installation

Add to your `Gemfile`:

```ruby
gem "active_billing"
```

Then:

```bash
bundle install
rails active_billing:install:migrations
rails db:migrate
```

Requirements:

- Rails 6.0+
- PostgreSQL (uses `jsonb`, `hstore`, `gen_random_uuid()`)
- Ruby 2.7+

## Configuration

`config/initializers/active_billing.rb`:

```ruby
ActiveBilling.configure do |config|
  # Default currency for new Billings (ISO code)
  config.currency = :BRL

  # Default cycle interval for new Billings (:monthly, :weekly, or a Duration)
  config.default_cycle_interval = :monthly

  # Default penalty / interest applied to overdue Charges (in basis points; 200 = 2%)
  config.default_penalty  = 200
  config.default_interest = 100

  # Method called on resources to resolve the billable entity
  config.billing_entity_method = :billing_entity

  # Standalone mode: enable the mountable API and set auth callable
  config.api_enabled    = false
  config.api_authorizer = ->(request) { ApiToken.find_by(token: request.headers["X-Api-Key"]) }
end
```

## Embedded usage

### 1. Mark a billable entity

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

### 2. Define a Plan

```ruby
plan = ActiveBilling::Plan.create!(
  name: "Pro",
  recurring_amount: 99.00,           # stored in cents
  included_allowances: { api_call: 10_000, sms_sent: 200 },
  metadata: { tier: "pro" }
)
```

### 3. Open a Billing cycle

```ruby
billing = customer.billings.create!(
  plan: plan,                                    # snapshotted onto the billing
  cycle_start: Date.current.beginning_of_month,
  cycle_end:   Date.current.end_of_month,
  interval:    :monthly
)
```

Creating a Billing also opens a `Usage` for the cycle window.

### 4. Record events

```ruby
billing.usage.events.create!(
  kind: "api_call",
  resource: api_request,
  metadata: { endpoint: "/v1/users" },
  chargeable: true
)
```

### 5. Close the cycle

```ruby
billing.close!     # closes the Usage; computes usage-derived line items;
                   # adds plan recurring charge from the snapshot
```

### 6. Adjust the Billing

Between close and finalize, the Billing is editable. Use this window for credits, discounts, manual line items, or to combine extra Usages.

```ruby
billing.line_items.create!(key: "setup_fee", description: "One-time onboarding", quantity: 1, unit_price: 250.00)
billing.apply_credit!(amount: 50.00, reason: "loyalty")
billing.apply_discount!(percent: 10, reason: "promo")
billing.add_usage!(other_closed_usage)        # combine multiple Usages
```

### 7. Finalize → Invoice → Charge

```ruby
invoice = billing.finalize!     # locks the Billing, generates Invoice + items
invoice.issue!                  # creates a Charge in "created" state

# In v1, Charge state transitions are driven by your application or a
# payment-provider adapter you write. See "Payments" below.
charge = invoice.charge
charge.mark_processing!
charge.mark_paid!(paid_at: Time.current)
```

## Standalone usage

In standalone mode, external services interact with the engine over JSON. All endpoints are prefixed by the mount path (`/billing` below) and require the configured API auth header.

```http
POST /billing/api/v1/billings
Content-Type: application/json
X-Api-Key: <token>

{
  "billable_entity": { "type": "Customer", "id": "cus_123" },
  "plan_id": "plan_pro",
  "cycle_start": "2026-05-01",
  "cycle_end":   "2026-05-31",
  "interval":    "monthly"
}
```

```http
POST /billing/api/v1/billings/:id/events
{ "kind": "api_call", "metadata": { "endpoint": "/v1/users" }, "chargeable": true }

POST /billing/api/v1/billings/:id/close
POST /billing/api/v1/billings/:id/finalize
GET  /billing/api/v1/invoices/:id
```

Embedded callers get the same behavior by calling the model methods directly; standalone callers get it over HTTP. Both paths exercise identical domain logic.

## Payments

ActiveBilling v1 ships the **Charge state machine** (`created → processing → paid / failed / expired`) and an extension surface for payment providers, but it does **not** ship a Stripe/Pagar.me/etc. adapter. Wire your own provider via callbacks:

```ruby
ActiveBilling::Charge.after_create :send_to_gateway
ActiveBilling::Charge.after_paid   :reconcile_with_ledger
```

A pluggable provider interface (with a Stripe reference implementation) is on the roadmap — see `CHANGELOG.md` for status.

## Currency and money

All monetary values are stored as integer cents. The `CurrencyAttribute` concern adds a decimal accessor pair:

```ruby
invoice.amount = 99.99
invoice.amount_in_cents   # => 9999
invoice.amount            # => 99.99
```

Default currency is configured globally (`ActiveBilling.configuration.currency`) and can be overridden per Billing.

## Brazilian invoicing (NFe)

The `NfeDescription` concern produces NFe-compatible invoice descriptions when the host application issues Brazilian fiscal documents. It is opt-in and not required for general use.

## Customization

Override the gem's models in your app to add domain-specific behavior:

```ruby
class Plan < ActiveBilling::Plan
  # custom plan logic
end

class Billing < ActiveBilling::Billing
  def event_price_for(kind)
    # your pricing rules
  end
end
```

Common extension points:

- `Billing#event_price_for(kind)` — per-event pricing
- `Billing#calculate_event_cost(event)` — per-event cost calculation
- `Billing#close!` / `Billing#finalize!` — override or wrap with `super`
- `Charge` callbacks — payment-provider integration
- Custom `Event.kinds` entries — your own billable verbs

## Database schema

The gem creates the following tables (all prefixed `active_billing_`):

- `active_billing_plans` — plan catalog
- `active_billing_billings` — billing cycles
- `active_billing_usages` — per-cycle measurement buckets
- `active_billing_events` — individual billable events
- `active_billing_invoices` — invoice documents
- `active_billing_invoice_items` — invoice line items
- `active_billing_charges` — payment records

See `db/migrate/` for the authoritative schema and indexes.

## Project documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — data model, flows, design patterns
- [STRUCTURE.md](STRUCTURE.md) — file/directory layout
- [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) — practical recipes (plans, adjustments, standalone API)
- [CHANGELOG.md](CHANGELOG.md) — version history
- [CLAUDE.md](CLAUDE.md) — code style and conventions for contributors

## Contributing

Bug reports and pull requests are welcome on GitHub. Before submitting, run:

```bash
bundle exec rspec
bundle exec rubocop
```

Follow the conventions in [CLAUDE.md](CLAUDE.md) — they are enforced by review.

## License

MIT. See [MIT-LICENSE](MIT-LICENSE).
