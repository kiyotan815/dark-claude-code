---
name: ruby-testing
description: Use when writing Ruby tests or doing TDD in Ruby. Team decisions: RSpec primary (minitest allowed), FactoryBot, SimpleCov 80% floor.
---

# Ruby Testing

Team decisions for Ruby test suites. Assumes RSpec fluency — records choices, not tutorials.

## Framework

- **RSpec** is primary. **minitest** is acceptable when the project already uses it; same principles apply.
- TDD is mandatory: RED → GREEN → REFACTOR. Never write production code without a failing spec. See `rules/testing.md`.

## Conventions

- `describe` for class/method, `context` for conditions ("when X"), `it` reads as a sentence.
- Name subjects: `subject(:user)`, never bare `subject`.
- Verifying doubles required: `instance_double`, not bare `double` — prevents interface drift.
- Prefer `allow` + `have_received` over `expect(...).to receive` — separates setup from assertion.
- Shared examples sparingly; over-abstraction kills readability.

## Test Data

- **FactoryBot** over fixtures. Traits for variants; factory associations over `let` chains.
- `build` over `create` when persistence isn't needed.

## Doubles Policy

- Double only boundaries: external services, DB/IO, time/randomness. Never double the unit under test.
- Test observable behavior, not private method calls or implementation.

## Coverage

- SimpleCov with `minimum_coverage 80` (project floor, see `rules/testing.md`).
- Targets: models/domain and services **90%+**, controllers/API **80%+**; views via system specs.

## Speed & Isolation

- No `before(:all)` with DB writes — leaks state.
- Tag slow tests `:slow` and run them separately.
- System specs (Capybara + Selenium/Cuprite) for E2E browser flows only.
