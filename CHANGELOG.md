# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

This release reframes the gem around a **Billing** entity that owns one configured billing cycle, snapshots a **Plan**, aggregates closed **Usages**, and accepts adjustments before producing an Invoice. The gem also gains a first-class **standalone mode**: the same engine can be mounted in a thin Rails app to expose a JSON API consumed by external products.

> **Implementation status.** Entries below describe the intended design. Items not yet shipped are tagged **(planned)**; everything else in this section reflects code that exists today. See **Implemented in this release** for the concrete surface area added now.

### Implemented in this release
- `ActiveBilling::Plan` — minimal catalog model: `name`, `price_in_cents` (via `currency_attrs :price`), `interval` enum (`monthly`/`yearly`), `allowances` (jsonb), `active`, `metadata`. `#to_snapshot` returns the plan snapshot fields.
- `ActiveBilling::Billing` — connector/aggregator: polymorphic `billable_entity` (the payer — e.g. a chain or a single store), optional `plan`, plan **snapshot** fields, `state` enum (`open`/`finalized`), cycle window. `.current_for(entity)` returns the entity's latest open billing; `belongs_to`-snapshots the plan on validation while open. A single Billing can aggregate Usages from multiple resources to produce one unified Invoice/Charge.
- `billing_id` added to `active_billing_usages` and `active_billing_invoices`, plus uniform `for_billable_entity(type, id)` scopes on `Usage`, `Invoice`, and `Charge`.
- **Portal web UI** (read-only, scoped by `billable_entity_id`): `InvoicesController`, `UsagesController`, `ChargesController` (`index` + `show`) and `PlansController` (`show` — current plan). Ships ERB views + a layout the host app gets for free when the engine is mounted.
- **Override generators**: `active_billing:views` and `active_billing:controllers` copy the shipped views/controllers into the host app; `active_billing:install` writes a configuration initializer and prints setup steps.
- **Standalone JSON API** (`ActiveBilling::Api::V1`): versioned controllers + jbuilder serializers for every model, mounted under `/api/v1` and gated by `config.api_enabled`. Authenticates via `X-Api-Key` → `config.api_authorizer` (callable `->(api_key, request) { scope }`; `401` on reject, `403` when unset). Full CRUD guarded by the domain rules — soft delete for Billing/Invoice/Charge, plan deactivation vs. deletion, one-usage-per-cycle, empty-only usage deletion, append-only Events, and the Invoice state machine. Custom transitions are REST noun sub-resources: `PUT /billings/:id/plan`, `POST /billings/:id/finalization`, `POST /usages/:id/closure`, `POST /invoices/:id/issuance`, `POST /invoices/:id/cancellation`, `POST /charges/:id/payment`. Consistent `{ "error": { code, message, details } }` envelope.
- **API override generators**: `active_billing:api_controller <resource>`, `active_billing:api_views <resource>`, and `active_billing:api_base` eject a single controller/view set into the host app.
- **Guarded lifecycle transitions**: `Billing#finalize!` / `#associate_plan!`, `Usage#close!` (+ `closed_at` column, immutable once closed), `Invoice#issue!` / `#cancel!`. Soft delete (`Discard::Model` + `discarded_at`) on `Billing`, `Invoice`, and `Charge`.
- `config.billable_entity_class` — default polymorphic type for portal pages when `billable_entity_type` is not passed as a query param.
- `ActiveBilling.configuration` now lazily initializes (no need to call `configure` before reading defaults).
- RSpec test harness: `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb`, FactoryBot factories, model/request/routing specs, and a dummy `Store` billable model.
- `.rubocop.yml` encoding the project conventions (double quotes, no frozen-string comments, `->` lambdas).

### Changed (money handling)
- Replaced the `CurrencyAttribute` concern with a custom ActiveRecord attribute type. Added `ActiveBilling::Money` (immutable value object: integer cents + currency, `Comparable`, `to_d`/`as_json`) and `ActiveBilling::Type::Money` (registered as `:active_billing_money`). Models now declare `attribute :amount_in_cents, :active_billing_money` (also `total_cost_in_cents`, `price_in_cents`) instead of `currency_attrs`. Money is exposed as a `Money` value object (BigDecimal-backed, exact) and serialized to integer cents for the DB and JSON. Monetary validations now use `comparison:` against the value object. Removed `lib/active_billing/concerns/currency_attribute.rb`.

### Fixed
- Engine models in `lib/active_billing/models/` were never loaded (not required, and `lib/` is not an autoload path). They are now registered with Zeitwerk via an engine initializer.
- Model concern includes referenced the wrong constant (`include CurrencyAttribute` instead of `Concerns::CurrencyAttribute`), which raised `NameError` on load. Now namespaced.
- The initial migration was not runnable: it added a foreign key to `active_billing_invoices` before that table existed, and used `hstore` without enabling the extension. Both fixed.
- `ActiveBilling::Charge` could not be created — it included `Chargeable`, which defines `has_one :charge` and scopes against columns the `charges` table does not have. `Charge` no longer includes `Chargeable`; its own associations and helpers (`payer`, `billing_entity`, …) are unchanged.

### Added (planned — not yet implemented)
- `ActiveBilling::Billing` adjustment helpers (`add_usage!`, `apply_credit!`, `apply_discount!`).
- `ActiveBilling::BillingLineItem` — adjustments applied to a Billing between close and finalize.
- **Charge state machine** (`created → processing → paid / failed / expired`). Until it ships, the API's `POST /charges/:id/payment` responds `501`.

### Changed
- The canonical lifecycle is now **configure Billing → record Events → close Usage → adjust Billing → finalize → Invoice → Charge.** Usage no longer flows directly into Invoice; it flows into Billing first. _(Design target; the `close!`/`finalize!` helpers are planned.)_
- Plan recurring charges and usage-derived charges are unified onto the Billing's line items before invoice generation. _(Planned.)_

### Roadmap
- Pluggable **PaymentProvider** adapter interface with a Stripe reference implementation. v1 ships the Charge state machine + callbacks only.
- Outbound **webhooks** from standalone mode (`cycle.closed`, `invoice.issued`, `charge.paid`).
- **Idempotency keys** on all mutating API endpoints.
- Advanced pricing rules (tiered, graduated, contract-based).
- Automated dunning workflows.
- Multi-currency support.
- Pluggable tax-service integration.

## [0.1.0] - 2026-02-02

### Added
- Initial release of ActiveBilling gem
- Core models: Charge, Event, Invoice, InvoiceItem, Usage
- Concerns: Chargeable, NfeDescription, CurrencyAttribute, TimestampStoreAccessor
- Database migrations for PostgreSQL
- Comprehensive documentation and examples
- Support for usage-based and subscription billing
- Invoice lifecycle management
- Email tracking capabilities
- NFe integration support
