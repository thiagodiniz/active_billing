# ActiveBilling Gem Structure

This document describes the file structure of the ActiveBilling gem.

## Directory layout

```
active_billing/
├── active_billing.gemspec          # Gem specification
├── Gemfile                          # Development dependencies
├── Rakefile                         # Rake tasks
├── MIT-LICENSE                      # License file
├── .gitignore                       # Git ignore rules
│
├── README.md                        # Main documentation
├── CHANGELOG.md                     # Version history
├── ARCHITECTURE.md                  # Architecture decisions
├── USAGE_EXAMPLES.md                # Practical examples
├── STRUCTURE.md                     # This file
├── CLAUDE.md                        # Code style + contributor conventions
│
├── lib/
│   ├── active_billing.rb            # Main entry point + configuration
│   │
│   ├── active_billing/
│   │   ├── version.rb               # Version constant
│   │   ├── engine.rb                # Rails engine (mountable for standalone mode)
│   │   │
│   │   ├── concerns/                # Shared model behaviors
│   │   │   ├── chargeable.rb        # Payment-related behavior
│   │   │   ├── currency_attribute.rb # Money handling (cents ↔ decimal)
│   │   │   ├── nfe_description.rb   # Brazilian fiscal invoice description (opt-in)
│   │   │   └── timestamp_store_accessor.rb  # Email tracking via hstore
│   │   │
│   │   └── models/                  # Core domain models
│   │       ├── plan.rb              # Plan catalog
│   │       ├── billing.rb           # Configured billing cycle (new central model)
│   │       ├── billing_line_item.rb # Adjustments applied to a Billing
│   │       ├── usage.rb             # Per-period measurement bucket
│   │       ├── event.rb             # Append-only billable events
│   │       ├── invoice.rb           # Invoice document with state machine
│   │       ├── invoice_item.rb      # Invoice line items
│   │       └── charge.rb            # Payment record + state machine
│   │
│   └── tasks/
│       └── active_billing_tasks.rake # Rake tasks (install migrations, close cycles, …)
│
├── app/                             # Standalone-mode engine code
│   ├── controllers/
│   │   └── active_billing/
│   │       └── api/
│   │           └── v1/
│   │               ├── base_controller.rb
│   │               ├── billings_controller.rb
│   │               ├── events_controller.rb
│   │               ├── invoices_controller.rb
│   │               └── plans_controller.rb
│   └── serializers/
│       └── active_billing/
│           ├── billing_serializer.rb
│           ├── invoice_serializer.rb
│           ├── charge_serializer.rb
│           └── plan_serializer.rb
│
├── config/
│   └── routes.rb                    # Engine routes (mounted under host app's mount path)
│
├── db/
│   └── migrate/
│       ├── 20260101000001_create_active_billing_tables.rb
│       └── 20260101000002_create_active_billing_billings_and_plans.rb
│
└── spec/                            # RSpec test suite
    ├── spec_helper.rb
    ├── models/
    ├── concerns/
    ├── requests/                    # Standalone API tests
    └── support/
```

## Key files

### Configuration & setup

- **active_billing.gemspec** — gem metadata, dependencies, included files
- **lib/active_billing.rb** — main entry point, `ActiveBilling.configure` block
- **lib/active_billing/version.rb** — semantic version
- **lib/active_billing/engine.rb** — Rails engine; mountable for standalone mode

### Core models

Located in `lib/active_billing/models/`:

1. **plan.rb** — catalog entry: recurring price + included allowances
2. **billing.rb** — one configured billing cycle for a billable entity; snapshots a Plan; aggregates Usages + adjustments
3. **billing_line_item.rb** — line items added to a Billing (manual items, credits, discounts)
4. **usage.rb** — per-period measurement bucket; closes at cycle end, then immutable
5. **event.rb** — append-only billable events recorded against a Usage
6. **invoice.rb** — document produced when a Billing finalizes; state machine
7. **invoice_item.rb** — line items owned by an Invoice
8. **charge.rb** — payment record with its own state machine

### Concerns

Located in `lib/active_billing/concerns/`:

1. **chargeable.rb** — payment-related associations + scopes
2. **currency_attribute.rb** — `currency_attrs :amount` macro (cents ↔ decimal)
3. **nfe_description.rb** — Brazilian fiscal invoice description (opt-in)
4. **timestamp_store_accessor.rb** — email tracking timestamps in hstore

### Engine (standalone mode)

Located under `app/`:

- **controllers/active_billing/api/v1/** — versioned JSON controllers; require `config.api_enabled = true` and a `config.api_authorizer` callable
- **serializers/active_billing/** — JSON serialization of the public surface
- **config/routes.rb** — mounted by the host app via `mount ActiveBilling::Engine => "/billing"`

In embedded mode, the engine is loaded but its controllers refuse requests unless `api_enabled` is true. In standalone mode, the engine is the entire HTTP surface.

### Database

`db/migrate/` ships migrations for all tables:

- `active_billing_plans`
- `active_billing_billings`
- `active_billing_billing_line_items`
- `active_billing_usages`
- `active_billing_events`
- `active_billing_invoices`
- `active_billing_invoice_items`
- `active_billing_charges`

All tables use UUID secondary keys (`gen_random_uuid()`), `jsonb` for metadata, and `hstore` where key/value tracking is useful.

### Documentation

- **README.md** — install, configure, and use (both modes)
- **ARCHITECTURE.md** — data model, flows, design patterns
- **USAGE_EXAMPLES.md** — recipes (plans, adjustments, standalone API)
- **CHANGELOG.md** — version history
- **STRUCTURE.md** — this file
- **CLAUDE.md** — code style + RSpec conventions

### Tasks

`lib/tasks/active_billing_tasks.rake`:

- `active_billing:install:migrations` — copy migrations into host app
- `active_billing:cycles:close` — close all due cycles (intended for cron / scheduler)
- `active_billing:cycles:finalize` — finalize closed Billings ready for invoicing

## Install modes

### Embedded

1. Add `gem "active_billing"` to host Gemfile
2. Run migrations
3. Use the models directly: `Customer#billings`, `ActiveBilling::Plan.create!`, `billing.close!`, etc.
4. Leave `config.api_enabled = false` (default)

### Standalone

1. Create a thin Rails app
2. Add `gem "active_billing"` and any provider/auth gems
3. `mount ActiveBilling::Engine => "/billing"` in `config/routes.rb`
4. Set `config.api_enabled = true` and provide `config.api_authorizer`
5. External products call the JSON API; the engine drives the same domain models

Both modes are first-class. The standalone API is a thin transport layer over the embedded model API — every endpoint maps to a method on a model.

## Dependencies

### Runtime

- `rails` (>= 6.0)
- `discard` (~> 1.2) — soft deletes

### Development

- `rspec-rails` — testing
- `factory_bot_rails` — test data
- `rubocop` — lint
- `pry` — debugging

## Extension points

You can extend ActiveBilling by:

1. **Subclassing** `ActiveBilling::Billing` / `ActiveBilling::Plan` to add domain behavior
2. **Overriding** `event_price_for`, `calculate_event_cost`, `close!`, `finalize!`
3. **Adding** custom event kinds (`ActiveBilling::Event.kinds.merge!(...)`)
4. **Hooking** Charge callbacks for payment-provider integration
5. **Serving** standalone webhooks (roadmap) for `cycle.closed`, `invoice.issued`, `charge.paid`

## Testing

The repo uses RSpec. See `CLAUDE.md` for the testing conventions (`describe '.method' / '#method'`, `context "when..."`, one expectation per unit test, `let` over `before @vars`, FactoryBot, real DB over mocks for integration).

```bash
bundle exec rspec       # full suite
bundle exec rubocop     # lint
```

## Building the gem

```bash
gem build active_billing.gemspec
gem install ./active_billing-<version>.gem
gem push active_billing-<version>.gem        # publish (when ready)
```

## License

MIT — see `MIT-LICENSE`.
