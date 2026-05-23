# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

This release reframes the gem around a **Billing** entity that owns one configured billing cycle, snapshots a **Plan**, aggregates closed **Usages**, and accepts adjustments before producing an Invoice. The gem also gains a first-class **standalone mode**: the same engine can be mounted in a thin Rails app to expose a JSON API consumed by external products.

### Added
- `ActiveBilling::Billing` — central record representing one configured cycle for a billable entity (cycle window, interval, plan snapshot, aggregated Usages, adjustments). Lifecycle: `open → closed → finalized`.
- `ActiveBilling::Plan` — catalog model (recurring price + included allowances) snapshotted onto Billing at creation time.
- `ActiveBilling::BillingLineItem` — adjustments applied to a Billing between close and finalize (manual items, credits, discounts).
- Two-mode install: **embedded** (use models directly) and **standalone** (`mount ActiveBilling::Engine` with a JSON API).
- `config.api_enabled` and `config.api_authorizer` for the standalone-mode HTTP surface.
- `config.default_cycle_interval` configuration (`:monthly`, `:weekly`, or a custom Duration).
- Versioned JSON controllers under `ActiveBilling::Api::V1::*` for the standalone API.
- Documentation overhaul (README, ARCHITECTURE, STRUCTURE, USAGE_EXAMPLES) covering the new lifecycle and both install modes.

### Changed
- The canonical lifecycle is now **configure Billing → record Events → close Usage → adjust Billing → finalize → Invoice → Charge.** Usage no longer flows directly into Invoice; it flows into Billing first.
- Plan recurring charges and usage-derived charges are unified onto the Billing's line items before invoice generation.

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
