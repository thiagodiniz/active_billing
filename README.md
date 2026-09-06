# ActiveBilling

A Rails-focused Ruby gem for SaaS billing. ActiveBilling manages billing cycles, tracks plan-based and usage-based consumption, closes cycles, generates invoices, and records payment. It runs **embedded** inside an existing Rails application (models, controllers, jobs, helpers) or **standalone** as a thin billing service that receives input from external apps over a JSON API.

> **Implementation status.** This README documents both the shipped surface and the intended design. What's implemented today: the core models (`Plan`, `Billing`, `Usage`, `Event`, `Invoice`, `InvoiceItem`, `Charge`), the polymorphic billable-entity model, `billable_entity` scoping, and a **read-only portal web UI** with **override generators** (see [Web UI](#web-ui-portal)). Still **planned**: the Billing lifecycle helpers (`close!`, `finalize!`, …), `BillingLineItem` adjustments, and the **standalone JSON API**. Planned sections below are marked as such. See [CHANGELOG.md](CHANGELOG.md) for the authoritative status.

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

The migrations enable the `pgcrypto` and `hstore` PostgreSQL extensions automatically.

Requirements:

- Rails 6.0+ (developed/tested against Rails 8.1)
- PostgreSQL (uses `jsonb`, `hstore`, `gen_random_uuid()`)
- Ruby 2.7+ (developed/tested on Ruby 3.2)

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

  # Default polymorphic type used by the portal web UI when the
  # billable_entity_type query param is omitted (e.g. "Customer", "Store").
  config.billable_entity_class = nil

  # Base controller for the portal pages. Point it at your own controller so the
  # portal inherits your authentication, layout and CSRF configuration.
  config.parent_controller = "ActionController::Base"

  # Optional invoice description template (String or callable receiving the invoice).
  # Supports %{month} and %{uuids}.
  config.invoice_description = nil

  # Standalone mode (planned): enable the mountable API and set auth callable.
  # The config keys exist today; the API controllers/serializers are not yet shipped.
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

The shipped `Plan` model uses `name`, `price_in_cents` (a money-typed attribute — see [Currency and money](#currency-and-money)), `interval` (`monthly`/`yearly`), `allowances` (jsonb), and `active`:

```ruby
plan = ActiveBilling::Plan.create!(
  name: "Pro",
  price_in_cents: 9_900,                          # cents; or ActiveBilling::Money.from_amount(99.00)
  interval: "monthly",
  allowances: { api_call: 10_000, sms_sent: 200 },
  metadata: { tier: "pro" }
)

plan.price_in_cents        # => #<ActiveBilling::Money BRL 99.00>
plan.price_in_cents.to_d   # => 0.99e2 (BigDecimal, exact)
plan.price_in_cents.cents  # => 9900
```

### 3. Open a Billing cycle

`Billing` is the connector between a billable entity and its usages/invoices/charges. It belongs to a polymorphic `billable_entity` (the payer — a chain, a store, a customer…), optionally references a `Plan` (snapshotted onto the billing while it is `open`), and has a `state` of `open`/`finalized`.

```ruby
billing = customer.billings.create!(
  plan: plan,                                    # snapshotted onto the billing
  period_start: Date.current.beginning_of_month,
  period_end:   Date.current.end_of_month
)

ActiveBilling::Billing.current_for(customer)     # latest open billing for an entity
```

Because a Billing can aggregate `Usage` records from several resources, multiple stores under one chain can either be billed individually (one Billing each) or unified into a single Billing → Invoice → Charge.

> **Planned:** automatically opening a `Usage` when a Billing is created, and the `close!`/`finalize!` lifecycle helpers shown below, are not yet implemented. Create and associate `Usage` records directly for now.

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

> **Planned.** Steps 5–7 below (`close!`, the adjustment helpers, and `finalize!`) describe the target lifecycle and are **not yet implemented**. Today, build Invoices/Charges from Usages directly.

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

## Web UI (portal)

The engine ships a **read-only portal** that a host app gets for free once the engine is mounted. Every list is scoped to a billable entity via the `billable_entity_id` query param (and `billable_entity_type`, unless `config.billable_entity_class` is set). Authentication is intentionally out of scope — wrap the routes with your own app's auth, and set `config.parent_controller` so the portal controllers inherit it.

Mounted at the engine's path (e.g. `/billing`):

| Route | Action | Purpose |
| ----- | ------ | ------- |
| `GET /invoices` | index | Invoices for the billable entity (via their Billing) |
| `GET /invoices/:id` | show | One invoice + its items |
| `GET /usages` | index | Usages measured for the billable entity |
| `GET /usages/:id` | show | One usage |
| `GET /charges` | index | Charges for the billable entity (via invoice → billing) |
| `GET /charges/:id` | show | One charge |
| `GET /plan` | show | The current plan for the billable entity (from its open Billing) |

```
# Invoices for store #42, rendered by the engine's own views:
GET /billing/invoices?billable_entity_id=42&billable_entity_type=Store
```

Index actions return **400 Bad Request** when `billable_entity_id` (or a resolvable type) is missing. All user-facing strings go through `I18n.t` with English defaults in `config/locales/active_billing.en.yml`.

> **Note:** the portal is read-only (`index`/`show`). Create/update/destroy and an admin UI are not part of this surface.

## Overriding views and controllers

The shipped views/controllers are used as-is by default. To customize them, generate local copies into your app — Rails resolves your app's `app/views` and `app/controllers` ahead of the engine's:

```bash
# Copy the portal views into app/views/active_billing/** to override the defaults:
bin/rails generate active_billing:views

# Copy the portal controllers into app/controllers/active_billing/**:
bin/rails generate active_billing:controllers

# Write a config/initializers/active_billing.rb and print setup steps:
bin/rails generate active_billing:install
```

## Standalone usage

> **Planned.** The JSON API described in this section is **not yet implemented** — the `config.api_enabled` / `config.api_authorizer` keys exist, but the versioned controllers and serializers are on the roadmap. The example requests below document the intended contract.

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

> **Status.** `Charge` currently ships as a payment **record** (polymorphic `payer`/`resource`, optional `invoice`, default penalty/interest, `for_billable_entity` scope). The full **state machine** (`created → processing → paid / failed / expired`) and the `after_paid`-style callbacks below are **planned**.

ActiveBilling aims to ship the **Charge state machine** (`created → processing → paid / failed / expired`) and an extension surface for payment providers, but it does **not** ship a Stripe/Pagar.me/etc. adapter. Wire your own provider via callbacks:

```ruby
ActiveBilling::Charge.after_create :send_to_gateway
ActiveBilling::Charge.after_paid   :reconcile_with_ledger
```

A pluggable provider interface (with a Stripe reference implementation) is on the roadmap — see `CHANGELOG.md` for status.

## Currency and money

All monetary values are stored as integer cents. The `*_in_cents` columns use a custom ActiveRecord attribute type (`ActiveBilling::Type::Money`, registered as `:active_billing_money`) that casts them to an immutable `ActiveBilling::Money` value object:

```ruby
attribute :amount_in_cents, :active_billing_money   # declared on the model

invoice.amount_in_cents = 9_999          # assign cents…
invoice.amount_in_cents = ActiveBilling::Money.from_amount(99.99)  # …or from major units
invoice.amount_in_cents                  # => #<ActiveBilling::Money BRL 99.99>
invoice.amount_in_cents.cents            # => 9999
invoice.amount_in_cents.to_d             # => 0.9999e2 (BigDecimal — exact, not Float)
invoice.amount_in_cents.as_json          # => 9999  (stable integer serialization)
```

`Money` is `Comparable`, supports `+`/`-`, and serializes to integer cents — so validations (`comparison: { greater_than: 0 }`), JSON, and database round-trips stay exact. This replaced the earlier `CurrencyAttribute` concern; using a real type means casting/serialization is handled by Rails' attributes API instead of generated accessor methods.

Default currency is configured globally (`ActiveBilling.configuration.currency`) and used when building `Money` values.

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

- `Usage#event_price_for(kind)` — per-event pricing (override in your app; defaults to `0.0`)
- `Usage#calculate_event_cost(event)` — per-event cost calculation (override; defaults to `0.0`)
- `Usage#calculate_total_cost` — total cost across events
- `Charge#billing_entity` — return the entity that receives payments (must be overridden)
- Custom `Event.kinds` entries — your own billable verbs
- `Billing#close!` / `Billing#finalize!` — _planned_ lifecycle hooks

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
