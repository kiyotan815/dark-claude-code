---
name: php-testing
description: Use when writing PHP tests or doing TDD in PHP. Team decisions: PHPUnit primary (Pest allowed), coverage targets, test doubles policy.
---

# PHP Testing

Team decisions for PHP test suites. Assumes PHPUnit fluency — records choices, not tutorials.

## Framework

- **PHPUnit** is primary. **Pest** is acceptable (same engine); same principles apply.
- TDD is mandatory: RED → GREEN → REFACTOR. Never write production code without a failing test. See `rules/testing.md`.

## Layout & Conventions

- `tests/Unit`, `tests/Integration`, `tests/Feature` (Laravel naming); `Tests\` mapped via `autoload-dev` PSR-4.
- Use the `#[Test]` attribute (not `test_` prefix); method names read as snake_case sentences.
- `assertSame` over `assertEquals` — strict comparison catches type bugs.
- Enable `failOnWarning` / `failOnRisky` in `phpunit.xml`.

## Test Doubles Policy

- Double only at boundaries: external services, DB/filesystem, time/randomness. Never double the unit under test.
- Real objects over mocks for value objects and pure logic.
- Inject `Clock` (likewise Random/UUID) interfaces; test with frozen implementations — no wall-clock coupling.
- Test observable behavior, not internal method calls. Over-mocking = testing your mocks.

## Database & External Services

- Wrap each DB test in a rolled-back transaction (framework traits). No cross-test state.
- Factories for test data (Laravel factories / Foundry).
- Never hit real external APIs: stub the interface; use sandbox/mock servers for integration tests.

## Coverage Targets

- Domain logic / value objects: **95%+** · Services: **90%+** · Controllers: **80%+** (project floor: 80%, see `rules/testing.md`).
- Coverage is necessary, not sufficient — test behavior, not lines.

## Speed

- Unit tests run in milliseconds; tag slow ones `#[Group('slow')]`.
- Unit suite on save, full suite in CI.
