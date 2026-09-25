# ActiveBilling Architecture

This document describes the architecture and design decisions behind ActiveBilling.

> **Implementation status.** This document describes the target architecture. Implemented today: the domain models (`Plan`, `Billing`, `Usage`, `Event`, `Invoice`, `InvoiceItem`, `Charge`), the polymorphic billable-entity design, `for_billable_entity` scoping, the read-only **portal web UI**, the guarded lifecycle transitions (`Usage#close!`, `Billing#finalize!`, `Invoice#issue!`/`#cancel!`), and the standalone **JSON API** — all with override generators. **Planned** (marked inline): `BillingLineItem` adjustments and the full `Charge` state machine.

## Overview

ActiveBilling is a Rails engine gem that models the full SaaS billing lifecycle: configured **billing cycles**, **plan-based and usage-based** consumption, **cycle close**, **invoice** generation, and **payment** state. It is designed to run in two modes from a single codebase:

- **Embedded** — installed into a host Rails app; the host calls the gem's models, jobs, and helpers directly.
- **Standalone** — mounted as `ActiveBilling::Engine` inside a thin Rails app that exposes a JSON API consumed by external products.

Both modes share the same domain model and lifecycle. Standalone is the embedded engine plus an HTTP surface.

## Core concepts

### Billing — the central record

A `Billing` represents **one configured billing cycle for one billable entity**. It carries:

- the cycle window (`period_start`, `period_end`)
- a **snapshot** of the attached `Plan` (`plan_name`, `plan_price_in_cents`, `plan_allowances`) so plan catalog edits never rewrite past Billings
- references to one or more `Usage` records measured during the cycle (`has_many :usages`)
- a `state` of `open`/`finalized`
- _(planned)_ a collection of `BillingLineItem` adjustments (extra items, credits, discounts) added between close and finalize

A Billing is mutable until it is finalized. Finalization is intended to produce an `Invoice` (the `finalize!` helper is planned).

### Usage — the measurement

A `Usage` is the per-period measurement bucket for one billable entity. While the cycle is open, the host appends `Event` records (API calls, SMS sent, storage consumed, etc.) to it. At cycle end, the Usage is **closed**: no more events may be appended, and its derived line items are computed.

Usage and Billing are intentionally separate:

- Usage models *what was consumed*; once closed, it must never change (audit invariant).
- Billing models *what will be invoiced*; it is editable so credits, discounts, and manual items can be applied without violating the closed-Usage invariant.

### Plan

`Plan` is a catalog model owned by the gem: `name`, `price`/`price_in_cents`, `interval` (`monthly`/`yearly`), `allowances`, `active`, and metadata. When a Billing references a Plan, the Plan's relevant fields are **snapshotted** onto the Billing (`plan_name`, `plan_price_in_cents`, `plan_allowances`) on validation while the Billing is `open`. Future edits to the Plan catalog do not retroactively change past Billings.

### Invoice and Charge

The Invoice is the finalized billing document, with a working state machine (`created → processing → issued → cancelled / failed`). The Charge is the payment record attached to it. Today `Charge` ships as a record (payer/resource, optional invoice, penalty/interest, `for_billable_entity` scope); its full state machine (`created → processing → paid / failed / expired`), callback hooks, and payment-provider adapters (Stripe, Pagar.me, etc.) are roadmap.

## Lifecycle

```
1. Configure cycle      Billing.create!(plan:, cycle_start:, cycle_end:, interval:)
                        └─ snapshots Plan onto Billing; opens a Usage
2. Record consumption   billing.usage.events.create!(...)
3. Close cycle          billing.close!
                        └─ Usage state → "closed"; usage-derived items computed
                        └─ Plan recurring charge added from snapshot
4. Adjust               billing.line_items.create!(...), apply_credit!, apply_discount!,
                        add_usage!(other_closed_usage)
5. Finalize             billing.finalize!
                        └─ Invoice + InvoiceItems generated; Billing locked
6. Issue                invoice.issue!  → Charge created
7. Collect              charge.mark_processing! / mark_paid! / mark_failed!
```

## Data model

### Entity relationship diagram

> The diagram shows the target design. In the **implemented** models, `Plan` uses `price_in_cents`/`allowances` (not `recurring_amount`/`included_allowances`), `Billing` uses `period_start`/`period_end` and `state` is `open`/`finalized`, and `BillingLineItem` is planned.

```
┌─────────────────────────┐
│ Billable Entity         │  (host model: Customer, Organization, Tenant…)
│ (polymorphic)           │
└────────────┬────────────┘
             │ has_many
             ▼
┌─────────────────────────┐        ┌──────────────────────┐
│ Plan                    │◄───────│ Billing              │
│ - name                  │ snapshot│ - cycle_start         │
│ - recurring_amount      │         │ - cycle_end           │
│ - included_allowances   │         │ - interval            │
│ - metadata              │         │ - plan_snapshot       │
└─────────────────────────┘         │ - state (open / closed│
                                    │   / finalized)        │
                                    └──┬──────────┬─────────┘
                                       │          │
                            has_many   │          │ has_many
                                       ▼          ▼
                          ┌──────────────┐  ┌────────────────────┐
                          │ Usage        │  │ BillingLineItem    │
                          │ (closed at   │  │ (adjustments,      │
                          │  cycle end)  │  │  credits, discounts)│
                          └──────┬───────┘  └────────────────────┘
                                 │
                       has_many  │
                                 ▼
                          ┌──────────────┐
                          │ Event        │
                          │ (append-only)│
                          └──────────────┘

                          Billing ──finalize──► Invoice ──► InvoiceItem
                                                   │
                                                   ▼
                                                Charge
```

### Key relationships

- **Billable Entity → Billing**: one-to-many. A customer has one Billing per cycle.
- **Plan → Billing**: many-to-one *by reference*, one-to-one *by snapshot*. The Billing keeps its own copy of the plan fields it cares about.
- **Billing → Usage**: one-to-many. Usually 1:1, but multiple closed Usages can be combined into a single Billing.
- **Usage → Event**: one-to-many, append-only.
- **Billing → Invoice**: one-to-one. Finalizing a Billing produces exactly one Invoice.
- **Invoice → Charge**: one-to-many (in case of retries).

## Design patterns

### Snapshot, don't reference

The Plan attached to a Billing is *snapshotted*. The Billing holds its own copy of `plan_name`, `plan_price_in_cents`, and `plan_allowances`. This protects historical Billings from catalog edits and keeps audits straightforward.

### Two-phase consumption

Usage is the **measurement** phase (immutable once closed). Billing is the **assembly** phase (editable until finalized). This separation lets credits, discounts, and manual adjustments happen without touching the audit-critical Usage data.

### Polymorphic billable entity

`Billing` and `Usage` belong polymorphically to `billable_entity`. Host apps point it at any model that responds to the configured `billing_entity_method` (default: `:billing_entity`).

### Template-method pricing

`Billing#event_price_for(kind)` and `Billing#calculate_event_cost(event)` are extension points. Host apps override them in a subclass to plug in tiered pricing, volume discounts, etc.

### Concerns for cross-cutting behavior

- `TimestampStoreAccessor` — email tracking timestamps in `hstore`
- `NfeDescription` — opt-in Brazilian fiscal invoice description support

### Money as a custom attribute type

Monetary columns (`*_in_cents`) are mapped with a custom ActiveRecord type, `ActiveBilling::Type::Money` (registered as `:active_billing_money`), rather than a concern. The type casts the integer column to an immutable `ActiveBilling::Money` value object (cents + currency) and serializes it back to integer cents for the database and JSON. This keeps money exact (BigDecimal, never Float), centralizes casting/serialization in Rails' attributes API, and lets validations use value-object comparisons (`comparison: { greater_than: 0 }`). It replaced the earlier `CurrencyAttribute` concern, which generated cents/decimal accessor pairs via `define_method`.

### State machines via string-backed enums

```
Usage:    open      → closed
Billing:  open      → closed  → finalized
Invoice:  created   → processing → issued    → cancelled / failed
Charge:   created   → processing → paid / failed / expired
```

Transitions are guarded by `validate` methods, not by external state-machine gems.

## Billing as the resource ↔ billable-entity connector

`Billing` is what links the *thing being measured* to the *party that pays*. `Usage` records carry their own polymorphic `billable_entity` (e.g. an individual store), while `Billing` carries the polymorphic `billable_entity` of the payer (which may be that same store, or a parent like a chain). Because a `Billing` `has_many :usages` and `has_many :invoices`, several stores' usages can roll up into **one** Billing → Invoice → Charge (unified billing), or each store can keep its own Billing (per-store billing). This is why `Invoice` and `Charge` reach a billable entity *through* their `Billing` (`for_billable_entity` joins `active_billing_billings`), while `Usage` filters on its own columns.

## Web UI (portal)

The engine ships a small **read-only** web surface used directly when the engine is mounted:

- `PortalController` resolves the billable entity from `billable_entity_id` + `billable_entity_type` (the latter defaulting to `config.billable_entity_class`), and returns 400 on `index` when it is missing.
- `Invoices`/`Usages`/`Charges` expose `index` + `show`; `Plans` exposes `show` (the current plan from the entity's open `Billing`).
- Views are plain ERB resolved from the engine's view path. Hosts override them by generating local copies (`active_billing:views` / `active_billing:controllers`), which Rails resolves ahead of the engine's.

Authentication is deliberately left to the host app. An authenticated admin UI is not part of this surface.

## Two-mode architecture

### Embedded mode

The host Rails app `require`s the gem and calls `ActiveBilling::Billing.create!`, `ActiveBilling::Billing.current_for(entity)`, etc. directly, and may mount the engine for the read-only portal. (Lifecycle helpers like `billing.close!` are **planned**.)

### Standalone mode

The standalone surface ships:

- a Rails engine (`ActiveBilling::Engine`) mountable at any path — **implemented**
- versioned JSON controllers under `ActiveBilling::Api::V1::*` with jbuilder serializers for every model — **implemented**
- a token auth contract: `config.api_authorizer` (`->(api_key, request) { scope }`) resolves the `X-Api-Key` header to an authorized caller — **implemented** (`nil` hook → 403, falsy return → 401)
- full CRUD guarded by the domain rules, with lifecycle transitions as REST noun sub-resources — **implemented**
- webhooks for "cycle closed", "invoice issued", "charge paid" — **planned**

The standalone API is a thin transport layer over the embedded model API — every endpoint maps to a method call on a domain model, so both modes exercise identical business logic and validations.

### Configuration

```ruby
ActiveBilling.configure do |config|
  config.api_enabled    = true
  config.api_authorizer = ->(api_key, _request) { ApiToken.find_by(token: api_key) }
end
```

When `api_enabled` is false (embedded mode default), every API route responds `404`.

## Data flow

### Event recording

```
host app action
    └─ resolve billing for the current cycle
       └─ append event to billing.usage (open Usage)
          └─ event persisted with metadata + chargeable flag
```

### Cycle close

```
scheduled job / manual trigger
    └─ Billing#close!
       ├─ Usage.transition_to(:closed)
       ├─ derive line items from usage events
       └─ append plan recurring charge from snapshot
```

### Adjustment + finalize

```
host app / admin
    └─ Billing#line_items.create!, apply_credit!, apply_discount!
    └─ Billing#finalize!
       ├─ recompute totals
       ├─ create Invoice + InvoiceItems
       └─ Billing.transition_to(:finalized)
```

### Issue + payment

```
host app / scheduled job
    └─ Invoice#issue!
       └─ create Charge in "created" state
    └─ payment-provider integration (host-owned in v1)
       └─ Charge#mark_processing! / mark_paid! / mark_failed!
```

## Performance considerations

### Critical indexes

```
billings:        (billable_entity_type, billable_entity_id, cycle_start)
                 (state)
usages:          (billable_entity_type, billable_entity_id, month) UNIQUE
                 (state)
events:          (billing_usage_id, kind)
                 (resource_type, resource_id)
invoices:        (state), (billing_id), (resource_type, resource_id)
charges:         (invoice_id), (state)
plans:           (name) UNIQUE-ish
```

### Query optimization

- `includes(:plan_snapshot, usage: :events)` for Billing queries
- Counter caches for `events_count` on Usage if event volume is high
- Batched event inserts (`Event.insert_all`) for high-throughput producers

### Aggregation strategies

For very high event volumes, denormalize per-kind counts onto Usage and update them via background jobs. The gem stays correct either way — denormalization is an optimization, not a requirement.

## Extension points

| Where                                          | What you override                                 |
| ---------------------------------------------- | ------------------------------------------------- |
| Subclass `ActiveBilling::Billing`              | Pricing, custom adjustments, lifecycle hooks      |
| Subclass `ActiveBilling::Plan`                 | Plan validation, derived fields                   |
| `ActiveBilling::Event.kinds.merge!(...)`       | Add custom event types                            |
| `ActiveBilling::Charge` callbacks              | Payment-gateway integration                       |
| `ActiveBilling::Invoice` callbacks             | Send to accounting system, NFe emission           |
| `config.api_authorizer`                        | Standalone-mode auth                              |

## Security considerations

- **Data integrity** — closed Usage is immutable; finalized Billing is immutable; invoice items are owned by Invoice.
- **Monetary precision** — all money stored as integer cents; exposed as `ActiveBilling::Money` value objects (BigDecimal-backed) via a custom attribute type.
- **Idempotency** — every Billing/Invoice/Charge carries a UUID; standalone endpoints accept an `Idempotency-Key` header (roadmap).
- **API auth** — standalone mode requires `config.api_authorizer` to be set; the engine refuses requests otherwise.

## Testing strategy

- **Unit tests** — validations, pricing, state transitions, snapshot integrity.
- **Integration tests** — full lifecycle (create Billing → close → adjust → finalize → issue → pay).
- **API tests** — round-trip every endpoint in standalone mode; assert auth is enforced.
- **Performance tests** — high event volume, multi-Usage Billings.

See `CLAUDE.md` for the RSpec conventions enforced in this repo.

## Roadmap

- **Payment-provider adapters** — pluggable `PaymentProvider` interface with Stripe as the reference implementation.
- **Webhooks** — outbound event delivery from standalone mode (`cycle.closed`, `invoice.issued`, `charge.paid`).
- **Idempotency keys** — first-class on all mutating API endpoints.
- **Real-time usage dashboards** — WebSocket updates for live consumption metrics.
- **Advanced pricing rules** — tiered, graduated, volume, contract-based.
- **Automated dunning** — retry policies + customer communication workflows.
- **Multi-currency** — currency conversion and multi-currency invoices.
- **Tax calculation** — pluggable tax-service integration.

## References

- [Rails Active Record Guide](https://guides.rubyonrails.org/active_record_basics.html)
- [Rails Engine Guide](https://guides.rubyonrails.org/engines.html)
- [PostgreSQL JSON Types](https://www.postgresql.org/docs/current/datatype-json.html)
