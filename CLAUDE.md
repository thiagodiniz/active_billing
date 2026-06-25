# CLAUDE.md — ActiveBilling

## Project Overview

ActiveBilling is a Rails engine gem for SaaS billing. It manages **billing cycles**, tracks **plan-based and usage-based** consumption, **closes** cycles, generates **invoices**, and records **payments**. Targets Rails 6.0+ with PostgreSQL.

The gem supports two install modes from the same codebase:

- **Embedded** — installed into an existing Rails app; models/jobs/controllers used directly.
- **Standalone** — `mount ActiveBilling::Engine` in a thin Rails app to run as a billing service with a JSON API consumed by external products.

### Domain model (read before editing models)

| Model         | Role                                                                          |
| ------------- | ----------------------------------------------------------------------------- |
| `Plan`        | Catalog entry: recurring price + included allowances. Snapshotted onto Billing. |
| `Billing`     | One configured billing cycle for a billable entity. Aggregates Usages + plan snapshot + adjustments (line items, credits, discounts). Mutable until finalized. |
| `Usage`       | Per-period measurement bucket. Open while the cycle runs; **closed** at cycle end and immutable thereafter. |
| `Event`       | Append-only billable action recorded against a Usage.                         |
| `Invoice`     | Document produced when a Billing is finalized. State-machine: created → processing → issued → cancelled / failed. |
| `InvoiceItem` | Line item owned by an Invoice.                                                |
| `Charge`      | Payment record + state machine. Payment-provider adapters are roadmap; v1 ships state model only and exposes callbacks. |

Lifecycle: **configure Billing → record Events → close Usage → adjust Billing → finalize → Invoice → Charge.** Never bypass this order in new code.

Model naming is locked — do not rename `Usage`, `Event`, `Invoice`, `InvoiceItem`, or `Charge`. `Billing` and `Plan` are the only new top-level models.

## Commands

```bash
bundle exec rspec           # Run tests
bundle exec rubocop         # Lint
bundle exec rake db:migrate # Run migrations (test app)
```

## Code Style

### Ruby Conventions

- **Double quotes** for all strings; single quotes only in enums or gemspec
- **Symbol-colon hash syntax** (`key: value`); arrow syntax only for string/dynamic keys
- **Short methods** (3-10 lines typical; 10-30 only for callback chains)
- **Guard clauses** with early `return` — avoid deep nesting
- **Safe navigation** (`&.`) for nil-safe chains
- **Freeze constants**: `SCOPES = %w[paid expired cancelled].freeze`
- **No frozen string literal comments**
- **Minimal comments** — code should be self-documenting; comments explain *why*, not *what*; use comments for extension points

### Naming

- `snake_case` for methods, variables, filenames
- `CamelCase` for classes/modules
- `?` suffix for boolean predicates (`cancellable?`, `issuable?`, `paid?`)
- `_in_cents` suffix for monetary integer fields (`amount_in_cents`)
- `_at` suffix for timestamp fields (`issued_at`, `paid_at`)
- Table names prefixed with `active_billing_` (engine namespace)

### Module & Class Organization

- One class per file under `lib/active_billing/models/` and `lib/active_billing/concerns/`
- All models inherit from `ActiveRecord::Base`
- Concerns use `extend ActiveSupport::Concern` with `included do` blocks
- Namespace everything under `ActiveBilling::` (e.g. `ActiveBilling::Concerns::Chargeable`, `ActiveBilling::Type::Money`)
- Composition over inheritance — use concerns and polymorphic associations, not deep class hierarchies

### Models — Internal Block Ordering

Every model must follow this strict top-to-bottom ordering. Separate each section with a blank line.

```ruby
class Invoice < ActiveRecord::Base
  # 1. Includes (concerns, modules)
  include ActiveBilling::Concerns::TimestampStoreAccessor
  include ActiveBilling::Concerns::Chargeable

  # 2. Constants
  FINISHED_STATES = %w[cancelled failed].freeze

  # 3. Parameterless macros (gems that hook into the model)
  has_paper_trail

  # 4. Attribute macros (attr_accessor, store_accessor, attribute types, etc.)
  attr_accessor :skip_validation

  timestamp_store_accessor :email_timestamps

  attribute :amount_in_cents, :active_billing_money

  # 5. Associations — in this order: belongs_to, has_one, has_many, HABTM, others
  #    Use blank lines to group semantically related associations
  belongs_to :usage
  belongs_to :resource, polymorphic: true

  has_one :charge

  has_many :items, class_name: "ActiveBilling::InvoiceItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true

  has_one_attached :document

  # 6. Enums
  enum :state, { created: "created", processing: "processing", issued: "issued" }

  # 7. Validations (validates first, then custom validate)
  validates :state, presence: true
  validates :amount_in_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :items_must_be_present_when_issued

  # 8. Callbacks — ordered by lifecycle (before_validation → before_create → after_create → ...)
  before_validation :set_amount
  before_validation :set_description
  before_validation :set_issued_at
  after_create :notify_billing_entity

  # 9. Scopes
  scope :issued, -> { where(state: "issued") }
  scope :for_month, ->(date) { where(month: date.beginning_of_month) }

  # 10. Delegations and aliases
  delegate :expired?, :paid?, to: :charge, allow_nil: true
  alias payer resource

  # 11. Class methods
  def self.generate_for(usage)
    # ...
  end

  # 12. Public instance methods
  def cancellable?
    # ...
  end

  private

  # 13. Private class methods
  def self.default_description
    # ...
  end

  # 14. Private instance methods
  def set_amount
    # ...
  end

  # 15. Private custom validation methods
  def items_must_be_present_when_issued
    # ...
  end
end
```

#### Model Rules

- **Enums**: string-backed — `enum :field, { key: "value" }`
- **Scopes**: always lambda syntax — `scope :name, ->(arg) { ... }`
- **Validations**: `validates` (Rails DSL) before `validate` (custom methods)
- **Callbacks**: respect lifecycle order (`before_validation` before `before_create` before `after_create`, etc.)
- **Associations**: `belongs_to` → `has_one` → `has_many` → `HABTM` → `has_one_attached`; place `accepts_nested_attributes_for` directly after its `has_many`
- **Polymorphic associations** for flexible resource types: `belongs_to :resource, polymorphic: true`
- **Delegation**: `delegate :method, to: :association, allow_nil: true`
- **Aliasing**: `alias payer resource` for semantic clarity
- **Soft deletes** via `Discard::Model` (included in section 1)
- **Blank lines between sections** — never between items within the same section (except semantic grouping in associations)

### Concerns (Metaprogramming Patterns)

- `class_eval` for dynamic scope generation (Chargeable)
- `store_accessor` for hstore fields (TimestampStoreAccessor)
- Keep metaprogramming in concerns, not in models
- Prefer a custom `ActiveRecord::Type` over accessor-generating concerns for value casting/serialization (e.g. `ActiveBilling::Type::Money` for `*_in_cents` columns)

### Configuration

```ruby
ActiveBilling.configure do |config|
  config.currency = :BRL
  config.default_penalty = 200      # in cents
  config.default_interest = 100     # in cents
  config.billing_entity_method = :billing_entity
end
```

- Use `class << self` with `attr_accessor :configuration` at module level
- `Configuration` class with sensible defaults in `initialize`
- Extension via template method pattern: override `event_price_for`, `calculate_event_cost` in app

### Error Handling

- Custom `ActiveBilling::Error < StandardError` — keep it simple
- Add to `errors` on model for validation failures: `errors.add(:items, :invalid, message: '...')`
- Guard clauses in callbacks to bail early on invalid state

### Database Conventions

- **UUIDs** for external reference: `default: -> { "gen_random_uuid()" }`
- **Integer cents** for all monetary values — never floats
- **JSONB** for flexible metadata: `metadata, default: {}, null: false`
- **hstore** for key-value storage (email timestamps)
- **Polymorphic columns**: `_type` + `_id` pairs
- **Unique compound indexes** on natural keys (e.g. `[billable_entity_type, billable_entity_id, month]`)
- **Index** on every foreign key, enum/state column, and UUID

### Testing (RSpec)

#### Structure & Descriptions

- **Describe methods with Ruby conventions**: `.method` or `::method` for class methods, `#method` for instance methods — never plain text descriptions like `describe 'the authenticate method'`
- **Contexts start with "when", "with", or "without"**: `context "when logged in"`, `context "without a valid token"`
- **Keep `it` descriptions under 40 characters** — if too long, split into context + short `it`. Prefer one-liners when possible: `it { is_expected.to be_valid }`
- **Never use "should" in descriptions** — use third-person present tense: `"returns the total"`, `"does not change timings"`, not `"should return the total"`
- **Test all cases**: valid, edge, and invalid. For a destroy action, test when found, not found, and not owned

```ruby
# Good
describe "#cancel" do
  context "when invoice is issued" do
    it { is_expected.to change(invoice, :state).to("cancelled") }
  end

  context "when invoice is already cancelled" do
    it "raises a validation error" do
      expect { cancel }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end

# Bad
describe "cancelling an invoice" do
  it "should cancel the invoice when it is issued and raise error when already cancelled" do
  end
end
```

#### Single Expectation per Test

- **One assertion per `it` block** in unit specs — aids error identification
- **Multiple expectations are acceptable** in integration/database tests for performance reasons

```ruby
# Good (unit)
it { is_expected.to validate_presence_of(:kind) }
it { is_expected.to belong_to(:resource) }

# Good (integration — multiple expectations OK)
it "creates an invoice with items" do
  expect(invoice).to be_persisted
  expect(invoice.items.count).to eq(3)
end
```

#### Setup & Data

- **`let` over instance variables** — never use `before` blocks to assign `@vars`
- **`let`** (lazy) for data that may not be needed in every test; **`let!`** (eager) only when records must exist before the test runs
- **`subject` for the object under test** — use named subjects for clarity: `subject(:invoice) { build(:invoice) }`
- **`is_expected.to`** for one-liner expectations on the implicit subject
- **FactoryBot over fixtures** — use `create`, `build`, `build_stubbed`, and traits
- **Create only the data you need** — avoid loading excessive records; use `create_list` only when testing collection behavior
- **Factories with traits** for variations: `create(:invoice, :issued)` over manually setting attributes

```ruby
# Good
subject(:invoice) { build(:invoice, usage: usage) }
let(:usage) { create(:usage, billable_entity: customer) }
let(:customer) { create(:customer) }

it { is_expected.to be_valid }

# Bad
before do
  @customer = Customer.create!(name: "Test", email: "t@t.com")
  @usage = Usage.create!(billable_entity: @customer, month: Date.today)
  @invoice = Invoice.new(usage: @usage)
end
```

#### Mocking & HTTP

- **Prefer real behavior over mocks** — mock only external boundaries (APIs, emails, time)
- **WebMock for HTTP stubbing** — never hit real external services in tests
- **VCR cassettes** with `record: :none` for complex API interactions
- **`allow().to receive()`** syntax for stubs; avoid `allow_any_instance_of` when possible

#### Shared Examples

- **Use `it_behaves_like` / `include_examples`** to eliminate duplicated test logic across specs
- Best suited for shared behavior (concerns, interfaces) — models that differ significantly should have their own specs

```ruby
# Good
shared_examples "a chargeable record" do
  it { is_expected.to respond_to(:paid?) }
  it { is_expected.to respond_to(:expired?) }
end

describe ActiveBilling::Invoice do
  it_behaves_like "a chargeable record"
end
```

#### Matchers & Assertions

- **`expect` syntax only** — configure `c.syntax = :expect` in spec_helper
- **Readable matchers**: `expect { action }.to change(Model, :count).by(1)`, `expect(result).to include(key: value)`
- **Negated matchers** for clarity: define `not_change`, `exclude` via `RSpec::Matchers.define_negated_matcher`
- **`raise_error` with class**: `expect { call }.to raise_error(ActiveBilling::Error)` — always specify the error class

### I18n

- All user-facing strings use `I18n.t` with `default:` fallback
- Scope: `active_billing.<model>.<key>`

### Key Design Principles

1. **Monetary precision** — always store and compute in cents (integers)
2. **Polymorphic flexibility** — works with any billable entity or resource type
3. **Template method pattern** — provide override hooks, not configuration flags
4. **Composable scopes** — chainable query interfaces (`for_month.without_invoices.with_invoice_state`)
5. **State via enums** — string-backed enums for state machines with validation guards
6. **Callback ordering** — `before_validation` chain handles derived state (amount, description, timestamps)
