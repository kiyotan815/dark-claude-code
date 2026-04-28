---
name: ruby-testing
description: Ruby testing strategies using RSpec (primary) and minitest. Covers TDD red-green-refactor, doubles/mocks, fixtures, shared examples, and coverage requirements for maintainable Ruby test suites.
---

# Ruby Testing

TDD-first testing for Ruby projects. RSpec is the default; minitest noted where relevant.

## TDD Red-Green-Refactor

1. **Red** — write a failing spec that describes desired behavior
2. **Green** — minimum code to pass
3. **Refactor** — clean up, keeping the spec green

Never write production code without a failing spec first.

## RSpec Basics

### File Structure

```
spec/
  spec_helper.rb
  rails_helper.rb           # Rails projects only
  models/
    user_spec.rb
  services/
    payment_processor_spec.rb
  support/
    shared_examples.rb
```

### `describe`, `context`, `it`

```ruby
RSpec.describe PaymentProcessor do
  describe "#charge" do
    context "when card is valid" do
      it "returns a successful result" do
        processor = PaymentProcessor.new(card: valid_card)
        result = processor.charge(100)
        expect(result).to be_successful
      end
    end

    context "when card is declined" do
      it "raises PaymentDeclined" do
        processor = PaymentProcessor.new(card: declined_card)
        expect { processor.charge(100) }.to raise_error(PaymentDeclined)
      end
    end
  end
end
```

- `describe` for classes/methods
- `context` for branches/conditions ("when X", "with Y")
- `it` reads as a sentence: "it returns a successful result"

### `subject` and `let`

```ruby
RSpec.describe User do
  subject(:user) { described_class.new(name: "Alice", age: 30) }
  let(:admin) { User.new(name: "Bob", role: :admin) }

  it { is_expected.to be_valid }       # one-liner using subject

  describe "#display_name" do
    it "uses the name" do
      expect(user.display_name).to eq("Alice")
    end
  end
end
```

- `let` is **lazy** (computed on first call, cached per example)
- `let!` is eager (computed before each example) — use for DB seeds
- `subject` defines the implicit subject of the spec block
- Name them: `subject(:user)` is more readable than bare `subject`

### Common Matchers

```ruby
expect(value).to eq(expected)         # ==
expect(value).to eql(expected)        # eql? (type-strict)
expect(value).to be(expected)         # equal? (object identity)
expect(value).to be_truthy / be_falsey
expect(value).to be_nil
expect(collection).to include(item)
expect(collection).to contain_exactly(a, b, c)  # order-agnostic
expect(string).to match(/pattern/)
expect { code }.to raise_error(ErrorClass)
expect { code }.to change { state }.from(0).to(1)
expect { code }.to change(User, :count).by(1)
```

## Doubles and Mocks

### When to Use

Use doubles to **isolate** the unit under test from collaborators, especially:
- External services (HTTP, payment gateways)
- Slow dependencies (DB, file I/O)
- Non-deterministic things (time, randomness)

**Don't** double the thing you're testing.

### `instance_double` (Verifying Doubles)

```ruby
mailer = instance_double(UserMailer)
allow(mailer).to receive(:welcome).and_return(true)

expect(mailer).to have_received(:welcome).with(user)
```

`instance_double` verifies the method exists on the real class — prevents drift.

### Stubs vs Mocks

```ruby
# Stub: provide canned return value
allow(api).to receive(:fetch).and_return({ status: "ok" })

# Mock: assert it was called
expect(api).to receive(:fetch).with(id: 42).once
api.fetch(id: 42)
```

Prefer `allow` + `have_received` over `expect`-with-`to receive` — separates setup from assertion.

## Fixtures and Factories

### FactoryBot (Recommended)

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    name { "Alice" }
    email { "alice@example.com" }

    trait :admin do
      role { :admin }
    end
  end
end

# in specs
user = create(:user)               # persisted
admin = build(:user, :admin)       # not persisted
```

### Avoid `let` Chains for Object Setup

```ruby
# Bad — fragile and hard to read
let(:org) { create(:org) }
let(:team) { create(:team, org: org) }
let(:user) { create(:user, team: team) }

# Good — factory associations
factory :user do
  association :team
end
let(:user) { create(:user) }
```

## Shared Examples

```ruby
# spec/support/shared_examples.rb
RSpec.shared_examples "an authenticatable resource" do
  it "has a hashed password" do
    expect(subject.password_digest).to be_present
    expect(subject.password_digest).not_to eq(subject.password)
  end
end

# in specs
RSpec.describe User do
  subject { build(:user) }
  it_behaves_like "an authenticatable resource"
end
```

Use sparingly — over-abstraction kills test readability.

## Hooks

```ruby
RSpec.describe Order do
  before(:each) { Timecop.freeze(Time.zone.local(2026, 1, 1)) }
  after(:each)  { Timecop.return }

  before(:all) { @global_setup = expensive_thing }  # use carefully — leaks state
end
```

Order: `before(:all)` → `before(:each)` → `it` → `after(:each)` → `after(:all)`

## Coverage

### SimpleCov

```ruby
# spec/spec_helper.rb (very top, before requiring app code)
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage 80
end
```

### Targets

- **Models / domain logic**: 90%+
- **Controllers / API**: 80%+
- **Service objects**: 90%+
- **Views / helpers**: lower (hard to unit test, prefer system specs)

Coverage is necessary but not sufficient. **Test behavior, not lines.**

## minitest (Alternative)

When the project uses minitest instead:

```ruby
require "minitest/autorun"

class UserTest < Minitest::Test
  def setup
    @user = User.new(name: "Alice")
  end

  def test_valid
    assert @user.valid?
    assert_equal "Alice", @user.name
    assert_raises(PaymentDeclined) { @user.charge!(-1) }
  end
end
```

Minitest is faster, simpler. Same TDD principles apply.

## System Specs (Rails)

For end-to-end browser tests:

```ruby
RSpec.describe "User signup", type: :system do
  it "creates a new account" do
    visit "/signup"
    fill_in "Email", with: "alice@example.com"
    fill_in "Password", with: "secret123"
    click_button "Sign up"

    expect(page).to have_content("Welcome, alice@example.com")
  end
end
```

Use Capybara + Selenium/Cuprite for JS-heavy pages.

## Anti-patterns

### Testing Implementation, Not Behavior

```ruby
# Bad — coupled to private method names
it "calls #internal_helper" do
  expect(subject).to receive(:internal_helper)
  subject.do_thing
end

# Good — tests the observable outcome
it "produces the expected result" do
  expect(subject.do_thing).to eq(expected)
end
```

### Over-Mocking

If your test doesn't break when you change the implementation but the behavior is now wrong, you've mocked too much. Real objects > mocks when feasible (especially for value objects, simple collaborators).

### Slow Suites

- Avoid `before(:all)` with DB writes — leaks state
- Use `build` over `create` when persistence isn't needed
- Tag slow tests: `it "does heavy work", :slow do ... end`, run separately
