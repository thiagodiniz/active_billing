# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Payment provider interface (`ActiveBilling::Providers::Base`), registry (`ActiveBilling::Providers`), normalized `Result` / `WebhookEvent` values and an in-memory `:test` adapter. Concrete `:stripe`, `:polar` and `:abacatepay` adapters implement the same contract.
- `config.provider(name, **settings)`, `default_provider`, `provider_resolver`, `provider_sync_enabled` and `provider_sync_async` configuration.
- `ProviderAccount` (per-billable-entity provider + remote customer id) and `ProviderReference` (remote ids for plans, subscriptions, …). Each account can live on a different provider.
- `Concerns::ProviderSyncable` + `Providers::Synchronizer` / `ProviderSyncJob`: plans, subscriptions (`Billing`), customers and charges are mirrored to the provider when created or changed.
- `Charge` state machine (`created → pending → processing → paid / failed / expired / cancelled`) with `provider`, `external_id`, `payment_url`, `paid_at` / `failed_at` / `expired_at`. Issuing an `Invoice` now creates and submits a `Charge` when the payer has a provider.
- `POST /webhooks/:provider` endpoint (`Providers::WebhookProcessor`) verifying signatures and applying payment / subscription events.

### Fixed (code review follow-up)
- `Invoice` no longer writes to the database while validating. `remove_items_from_removed_usages`/`add_items_from_added_usages` ran `destroy_all` in a `before_validation` callback, so a bare `invoice.valid?` deleted `InvoiceItem` rows outside any transaction. Item reconciliation is now in-memory (`mark_for_destruction` + `items.build`) and applied by autosave when the record is saved.
- `Invoice#add_usages_ids` treated an assigned `[]` as "keep the current usages", making it impossible to remove every usage.
- `Invoice` accepts a zero amount (`greater_than_or_equal_to: 0`), so credited and free-trial invoices are valid.
- `Invoice#set_description` no longer raises `I18n::MissingTranslationData`: the date format is shipped as `active_billing.invoice.month_format` instead of relying on an `en.date.formats.month` the gem never defined.
- `Concerns::NfeDescription` no longer assumes the resource responds to the configured `billing_entity_method`; it raised `NoMethodError` for any host model without it.
- `Usage` declares `belongs_to :billable_entity, polymorphic: true` — the columns and scopes existed but the association did not, so `usage.billable_entity` raised `NoMethodError`.
- `Event#resource` is `optional: true`, matching the nullable column.

### Removed
- `Concerns::Chargeable`. It could not be included by any model: it declared `has_one :charge, as: :chargeable` against a table with `resource_type/resource_id`, a `gateway_wallet` association with no model, scopes delegating to `Charge` scopes that do not exist, a join aliasing a table it never aliased, and ~25 delegations to non-existent columns. It will come back with the `Charge` state machine.
- `discard` and `jbuilder` runtime dependencies (only the deleted concern used `discard`; nothing used `jbuilder`), along with `Event#resource_with_discarded`.

### Added
- `config.parent_controller` — the portal controllers inherit from it, so the host app's authentication, layout and CSRF configuration apply to engine pages.
- `config.invoice_description` — String or callable used as the invoice description template, replacing host-specific method probing.

### Changed
- The gemspec declares `rails >= 7.0` and `required_ruby_version >= 3.2`. The code uses `enum :state, {...}` with `default:`, `Date#before?` and `Migration[7.0]`, none of which work on the previously declared Rails 6.0.

This release reframes the gem around a **Billing** entity that owns one configured billing cycle, snapshots a **Plan**, aggregates closed **Usages**, and accepts adjustments before producing an Invoice. The gem also gains a first-class **standalone mode**: the same engine can be mounted in a thin Rails app to expose a JSON API consumed by external products.

> **Implementation status.** Entries below describe the intended design. Items not yet shipped are tagged **(planned)**; everything else in this section reflects code that exists today. See **Implemented in this release** for the concrete surface area added now.

### Implemented in this release
- `ActiveBilling::Plan` — minimal catalog model: `name`, `price_in_cents` (via `currency_attrs :price`), `interval` enum (`monthly`/`yearly`), `allowances` (jsonb), `active`, `metadata`. `#to_snapshot` returns the plan snapshot fields.
- `ActiveBilling::Billing` — connector/aggregator: polymorphic `billable_entity` (the payer — e.g. a chain or a single store), optional `plan`, plan **snapshot** fields, `state` enum (`open`/`finalized`), cycle window. `.current_for(entity)` returns the entity's latest open billing; `belongs_to`-snapshots the plan on validation while open. A single Billing can aggregate Usages from multiple resources to produce one unified Invoice/Charge.
- `billing_id` added to `active_billing_usages` and `active_billing_invoices`, plus uniform `for_billable_entity(type, id)` scopes on `Usage`, `Invoice`, and `Charge`.
- **Portal web UI** (read-only, scoped by `billable_entity_id`): `InvoicesController`, `UsagesController`, `ChargesController` (`index` + `show`) and `PlansController` (`show` — current plan). Ships ERB views + a layout the host app gets for free when the engine is mounted.
- **Override generators**: `active_billing:views` and `active_billing:controllers` copy the shipped views/controllers into the host app; `active_billing:install` writes a configuration initializer and prints setup steps.
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
- `ActiveBilling::Billing` lifecycle helpers (`close!`, `finalize!`, `add_usage!`, `apply_credit!`, `apply_discount!`).
- `ActiveBilling::BillingLineItem` — adjustments applied to a Billing between close and finalize.
- Standalone **JSON API**: versioned controllers under `ActiveBilling::Api::V1::*`, serializers, and the `config.api_enabled` / `config.api_authorizer` HTTP surface (config keys exist; the controllers/serializers do not yet).

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
