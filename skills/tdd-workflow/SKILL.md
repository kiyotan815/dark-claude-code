---
name: tdd-workflow
description: Use when writing new features, fixing bugs, or refactoring. Enforces RED-GREEN-REFACTOR with 80%+ coverage across unit, integration, and E2E tests.
---

# TDD Workflow

Workflow contract for all code changes. Core rules live in `rules/testing.md` and the global `CLAUDE.md` (Development Philosophy) — this skill operationalizes them without repeating their explanations.

## Contract (RED → GREEN → REFACTOR)

1. For features, start from user journeys: "As a [role], I want [action], so that [benefit]".
2. **RED** — write tests first: happy path, edge cases (null/empty/boundary/large), and error paths. No production code yet.
3. Run the tests and confirm they fail. Commit the tests at this point (per global CLAUDE.md).
4. **GREEN** — write minimal implementation to pass. Never modify tests to fit the implementation (unless the test itself is wrong).
5. **REFACTOR** — improve naming, remove duplication, optimize — with tests staying green.
6. Verify coverage meets the floor before marking work complete.

## Coverage Requirement

- **80% minimum** across branches, functions, lines, statements — enforce via the test runner's threshold config. See `rules/testing.md`.
- Coverage is a floor, not a goal: test behavior, not lines.

## Three Test Types (all required)

- **Unit** — individual functions, component logic, pure logic. Fast (<50ms each); colocated next to source files (`Button.test.tsx`).
- **Integration** — API endpoints, DB operations, service interactions; colocated with routes/services (`route.test.ts`).
- **E2E** (Playwright) — critical user flows only; live in `e2e/`. Semantic selectors (`data-testid`, role/text), never CSS classes.

## Rules

- Mock only external boundaries (DB, HTTP, time); real objects within a unit.
- Tests are independent: each sets up its own data, no ordering dependencies, no leftover side effects.
- Test user-visible behavior, not implementation details or internal state.
- No skipped/disabled tests at completion; full suite green.
- Unit suite in watch mode during development; full suite + coverage in CI and pre-commit.

## Prove the Test Bites

For a critical invariant (tenant isolation, authorization, money), temporarily
break the implementation on purpose, confirm the test fails, then restore the
file and verify it is byte-identical (compare a checksum). A test that stays
green through the mutation is not testing the invariant.

## Support

- Delegating to Codex: put "TDD 厳守" and the unit-specific test file at the top of the prompt (`dcc:codex-delegate` skill).
- Review gate: `dcc:code-reviewer` agent after GREEN, before commit.
