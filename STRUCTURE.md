# ActiveBilling Gem Structure

This document describes the file structure of the ActiveBilling gem.

> **Legend.** Entries marked **(planned)** describe files that are part of the intended design but are **not yet present** in the repository. Everything else exists today.

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
│   │   │   ├── nfe_description.rb   # Brazilian fiscal invoice description (opt-in)
│   │   │   └── timestamp_store_accessor.rb  # Email tracking via hstore
│   │   │
│   │   ├── money.rb                 # Money value object (cents + currency)
│   │   ├── type/
│   │   │   └── money.rb             # ActiveRecord type for `*_in_cents` columns
│   │   │
│   │   ├── models/                  # Core domain models (Zeitwerk-autoloaded by the engine)
│   │   │   ├── plan.rb              # Plan catalog (name, price, interval, allowances)
│   │   │   ├── billing.rb           # Billing cycle / connector for a billable entity
│   │   │   ├── billing_line_item.rb # Adjustments applied to a Billing  (planned)
│   │   │   ├── usage.rb             # Per-period measurement bucket
│   │   │   ├── event.rb             # Append-only billable events
│   │   │   ├── invoice.rb           # Invoice document with state machine
│   │   │   ├── invoice_item.rb      # Invoice line items
│   │   │   └── charge.rb            # Payment record
│   │   │
│   │   └── generators/              # Override generators (copy engine files into host app)
│   │       └── active_billing/
│   │           ├── views/           # rails g active_billing:views
│   │           ├── controllers/     # rails g active_billing:controllers
│   │           ├── api_controller/  # rails g active_billing:api_controller <resource>
│   │           ├── api_views/       # rails g active_billing:api_views <resource>
│   │           ├── api_base/        # rails g active_billing:api_base
│   │           └── install/         # rails g active_billing:install (+ templates/)
│   │
│   └── tasks/
│       └── active_billing_tasks.rake # Rake tasks (install migrations, close cycles, …)
│
├── app/                             # Engine app code
│   ├── controllers/
│   │   └── active_billing/
│   │       ├── application_controller.rb
│   │       ├── portal_controller.rb        # Base: resolves billable_entity_id/type
│   │       ├── invoices_controller.rb      # Portal: index + show
│   │       ├── usages_controller.rb        # Portal: index + show
│   │       ├── charges_controller.rb       # Portal: index + show
│   │       ├── plans_controller.rb         # Portal: show (current plan)
│   │       └── api/                        # Standalone JSON API (ActiveBilling::Api::V1)
│   │           └── v1/
│   │               ├── base_controller.rb          # gate + auth + error envelope
│   │               ├── plans_controller.rb
│   │               ├── billings_controller.rb
│   │               ├── usages_controller.rb
│   │               ├── events_controller.rb
│   │               ├── invoices_controller.rb
│   │               ├── invoice_items_controller.rb
│   │               └── charges_controller.rb
│   ├── helpers/
│   │   └── active_billing/
│   │       └── application_helper.rb       # format_cents, etc.
│   ├── views/
│   │   ├── active_billing/                 # Portal ERB views (invoices/usages/charges/plans/shared)
│   │   │   └── api/v1/                     # jbuilder API views (one _partial + index/show per resource)
│   │   └── layouts/active_billing/
│
├── config/
│   ├── routes.rb                    # Engine routes (portal resources)
│   └── locales/
│       └── active_billing.en.yml    # I18n strings for models + portal
│
├── db/
│   └── migrate/
│       ├── 20260101000001_create_active_billing_tables.rb
│       ├── 20260615000001_create_active_billing_plans.rb
│       ├── 20260615000002_create_active_billing_billings.rb
│       └── 20260615000003_add_billing_to_usages_and_invoices.rb
│
├── spec/                            # RSpec test suite
│   ├── spec_helper.rb
│   ├── rails_helper.rb
│   ├── factories/
│   ├── models/active_billing/
│   ├── requests/active_billing/
│   └── routing/active_billing/
│
└── test/
    └── dummy/                        # Dummy Rails app used by the specs (incl. a Store model)
```

## Key files

### Configuration & setup

- **active_billing.gemspec** — gem metadata, dependencies, included files
- **lib/active_billing.rb** — main entry point, `ActiveBilling.configure` block
- **lib/active_billing/version.rb** — semantic version
- **lib/active_billing/engine.rb** — Rails engine; mountable for standalone mode

### Core models

Located in `lib/active_billing/models/` and autoloaded by the engine (Zeitwerk `push_dir` under the `ActiveBilling` namespace):

1. **plan.rb** — catalog entry: `name`, `price`/`price_in_cents`, `interval`, `allowances`, `active`
2. **billing.rb** — one billing cycle for a billable entity; snapshots a Plan; aggregates Usages (the connector that lets several resources share one Invoice/Charge)
3. **billing_line_item.rb** — line items added to a Billing (manual items, credits, discounts) — **(planned)**
4. **usage.rb** — per-period measurement bucket; `for_billable_entity` scope; pricing hooks
5. **event.rb** — append-only billable events recorded against a Usage
6. **invoice.rb** — document with a state machine; `belongs_to :billing`; `for_billable_entity` scope
7. **invoice_item.rb** — line items owned by an Invoice
8. **charge.rb** — payment record; `for_billable_entity` scope (full state machine **planned**)

### Concerns

Located in `lib/active_billing/concerns/`:

1. **chargeable.rb** — payment-related associations + scopes
2. **nfe_description.rb** — Brazilian fiscal invoice description (opt-in)
3. **timestamp_store_accessor.rb** — email tracking timestamps in hstore

### Money type

Monetary values use a custom ActiveRecord attribute type rather than a concern:

1. **lib/active_billing/money.rb** — `ActiveBilling::Money` value object (integer cents + currency; `Comparable`, `to_d`, `as_json` → cents)
2. **lib/active_billing/type/money.rb** — `ActiveBilling::Type::Money`, registered as `:active_billing_money` and applied to the `*_in_cents` columns via `attribute :amount_in_cents, :active_billing_money`

### Engine — portal web UI

Located under `app/`:

- **controllers/active_billing/** — `portal_controller.rb` (base; resolves `billable_entity_id`/`type`) and the read-only `invoices`, `usages`, `charges` (`index`+`show`) and `plans` (`show`) controllers
- **views/active_billing/** — ERB views for the portal, plus `layouts/active_billing/application.html.erb`
- **helpers/active_billing/application_helper.rb** — view helpers (e.g. `format_cents`)
- **config/routes.rb** — portal resources, mounted by the host app via `mount ActiveBilling::Engine => "/billing"`
- **config/locales/active_billing.en.yml** — I18n strings

### Override generators

Located under `lib/generators/active_billing/`:

- **views/** — `rails g active_billing:views` copies the portal views into the host app
- **controllers/** — `rails g active_billing:controllers` copies the portal controllers
- **api_controller/** — `rails g active_billing:api_controller <resource>` copies one API controller
- **api_views/** — `rails g active_billing:api_views <resource>` copies one resource's jbuilder views
- **api_base/** — `rails g active_billing:api_base` copies the API base controller
- **install/** — `rails g active_billing:install` writes a config initializer (template under `install/templates/`) and prints setup steps

### Engine — standalone JSON API

Located under `app/` (namespace `ActiveBilling::Api::V1`):

- **controllers/active_billing/api/v1/** — `base_controller.rb` (enforces `config.api_enabled`, authenticates `X-Api-Key` via `config.api_authorizer`, maps errors to a JSON envelope) plus one controller per model. Full CRUD guarded by the domain rules; custom transitions are REST noun sub-resources.
- **views/active_billing/api/v1/** — jbuilder serialization (`_<resource>.json.jbuilder` partial reused by `index`/`show`). Money renders as integer cents.

### Database

`db/migrate/` ships migrations for these tables:

- `active_billing_charges`, `active_billing_usages`, `active_billing_events`, `active_billing_invoices`, `active_billing_invoice_items` (initial migration)
- `active_billing_plans` and `active_billing_billings` (added this release)
- `billing_id` columns added to `active_billing_usages` and `active_billing_invoices`
- `active_billing_billing_line_items` — **(planned)**

The initial migration enables the `pgcrypto` and `hstore` extensions. All tables use UUID secondary keys (`gen_random_uuid()`), `jsonb` for metadata, and `hstore` where key/value tracking is useful.

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
- `active_billing:cycles:close` — close all due cycles (intended for cron / scheduler) — **(planned)**
- `active_billing:cycles:finalize` — finalize closed Billings ready for invoicing — **(planned)**

The engine also provides Rails generators (`active_billing:views`, `active_billing:controllers`, `active_billing:install`) for overriding the portal — see the generators section above.

## Install modes

### Embedded

1. Add `gem "active_billing"` to host Gemfile
2. Run migrations
3. Use the models directly: `Customer#billings`, `ActiveBilling::Plan.create!`, `ActiveBilling::Billing.current_for(entity)`, etc. (lifecycle helpers like `billing.close!` are **planned**)
4. Optionally mount the engine to get the read-only [portal web UI](README.md#web-ui-portal)

### Standalone (planned)

1. Create a thin Rails app
2. Add `gem "active_billing"` and any provider/auth gems
3. `mount ActiveBilling::Engine => "/billing"` in `config/routes.rb`
4. Set `config.api_enabled = true` and provide `config.api_authorizer`
5. External products call the JSON API; the engine drives the same domain models

The standalone JSON API is part of the intended design and is **not yet implemented**. The mountable engine and the portal UI work today.

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

1. **Overriding** `Usage#event_price_for`, `Usage#calculate_event_cost`, `Charge#billing_entity`
2. **Adding** custom event kinds via the `Event` enum
3. **Generating** local copies of the portal views/controllers (`active_billing:views` / `:controllers`) to customize the UI
4. **Hooking** Charge callbacks for payment-provider integration
5. **Overriding** `Billing#close!` / `Billing#finalize!` — _planned_ lifecycle hooks
6. **Serving** standalone webhooks for `cycle.closed`, `invoice.issued`, `charge.paid` — _planned_

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
