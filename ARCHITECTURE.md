# ActiveBilling Architecture

This document describes the architecture and design decisions behind ActiveBilling.

## Overview

ActiveBilling is a Rails engine gem that models the full SaaS billing lifecycle: configured **billing cycles**, **plan-based and usage-based** consumption, **cycle close**, **invoice** generation, and **payment** state. It is designed to run in two modes from a single codebase:

- **Embedded** — installed into a host Rails app; the host calls the gem's models, jobs, and helpers directly.
- **Standalone** — mounted as `ActiveBilling::Engine` inside a thin Rails app that exposes a JSON API consumed by external products.

Both modes share the same domain model and lifecycle. Standalone is the embedded engine plus an HTTP surface.

## Core concepts

### Billing — the central record

A `Billing` represents **one configured billing cycle for one billable entity**. It carries:

- the cycle window (`cycle_start`, `cycle_end`) and `interval` (monthly, weekly, or custom)
- a **snapshot** of the attached `Plan` (so plan catalog edits never rewrite past Billings)
- references to one or more closed `Usage` records measured during the cycle
- a collection of `BillingLineItem` adjustments (extra items, credits, discounts) added between close and finalize

A Billing is mutable until it is finalized. Finalization produces an `Invoice`.

### Usage — the measurement

A `Usage` is the per-period measurement bucket for one billable entity. While the cycle is open, the host appends `Event` records (API calls, SMS sent, storage consumed, etc.) to it. At cycle end, the Usage is **closed**: no more events may be appended, and its derived line items are computed.

Usage and Billing are intentionally separate:

- Usage models *what was consumed*; once closed, it must never change (audit invariant).
- Billing models *what will be invoiced*; it is editable so credits, discounts, and manual items can be applied without violating the closed-Usage invariant.

### Plan

`Plan` is a catalog model owned by the gem: recurring price + included allowances + metadata. When a Billing references a Plan, the Plan's relevant fields are **snapshotted** onto the Billing (`plan_name`, `plan_amount_in_cents`, `plan_allowances`, etc.). Future edits to the Plan catalog do not retroactively change past Billings.

### Invoice and Charge

The Invoice is the finalized, immutable billing document. The Charge is the payment record attached to it, with its own state machine (`created → processing → paid / failed / expired`). v1 ships the Charge state machine and callback hooks; payment-provider adapters (Stripe, Pagar.me, etc.) are roadmap.

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

The Plan attached to a Billing is *snapshotted*. The Billing holds its own copy of `plan_name`, `plan_amount_in_cents`, and `plan_allowances`. This protects historical Billings from catalog edits and keeps audits straightforward.

### Two-phase consumption

Usage is the **measurement** phase (immutable once closed). Billing is the **assembly** phase (editable until finalized). This separation lets credits, discounts, and manual adjustments happen without touching the audit-critical Usage data.

### Polymorphic billable entity

`Billing` and `Usage` belong polymorphically to `billable_entity`. Host apps point it at any model that responds to the configured `billing_entity_method` (default: `:billing_entity`).

### Template-method pricing

`Billing#event_price_for(kind)` and `Billing#calculate_event_cost(event)` are extension points. Host apps override them in a subclass to plug in tiered pricing, volume discounts, etc.

### Concerns for cross-cutting behavior

- `CurrencyAttribute` — `currency_attrs :amount` creates the cents/decimal accessor pair
- `Chargeable` — payment-related associations and scopes
- `TimestampStoreAccessor` — email tracking timestamps in `hstore`
- `NfeDescription` — opt-in Brazilian fiscal invoice description support

### State machines via string-backed enums

```
Usage:    open      → closed
Billing:  open      → closed  → finalized
Invoice:  created   → processing → issued    → cancelled / failed
Charge:   created   → processing → paid / failed / expired
```

Transitions are guarded by `validate` methods, not by external state-machine gems.

## Two-mode architecture

### Embedded mode

The host Rails app `require`s the gem, mounts nothing, and calls `ActiveBilling::Billing.create!`, `billing.close!`, etc. directly. All controllers/jobs/views are owned by the host.

### Standalone mode

The same gem ships:

- a Rails engine (`ActiveBilling::Engine`) mountable at any path
- versioned JSON controllers under `ActiveBilling::Api::V1::*`
- a token auth contract (`config.api_authorizer` resolves the request to an authorized caller)
- serializers for the public surface (Plan, Billing, Invoice, Charge)
- webhooks (roadmap) for "cycle closed", "invoice issued", "charge paid"

The standalone API is a thin transport layer over the embedded model API — every endpoint maps to a method call on a domain model. There is no parallel implementation.

### Configuration

```ruby
ActiveBilling.configure do |config|
  config.api_enabled    = true
  config.api_authorizer = ->(request) { ApiToken.find_by(token: request.headers["X-Api-Key"]) }
end
```

When `api_enabled` is false (embedded mode default), the engine's API controllers refuse all requests.

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
- **Monetary precision** — all money stored as integer cents; decimal accessors only at boundaries.
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
