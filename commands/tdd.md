---
description: Enforce test-driven development via the tdd-guide agent. Tests first (RED), minimal implementation (GREEN), refactor. 80%+ coverage.
---

# TDD Command

Invoke the **tdd-guide** agent to implement `$ARGUMENTS` test-first.

## Workflow

1. **Scaffold** - Define types/interfaces for inputs and outputs
2. **RED** - Write failing tests, run them, verify they fail for the right reason
3. **GREEN** - Write minimal implementation to make tests pass
4. **REFACTOR** - Improve code while keeping tests green
5. **Verify** - Check coverage is 80%+ (add tests if below)

## When to Use

- New features, functions, or components
- Bug fixes (first write a test that reproduces the bug)
- Refactoring critical business logic

## Rules

- Never write implementation before a failing test exists
- Never modify tests to make them pass (unless the test itself is wrong)
- Coverage requirements and test types (unit / integration / E2E) are defined
  in `rules/testing.md`; methodology details live in the `tdd-workflow` skill

## Related

- `/plan` before building
- `/build-fix` if build errors occur
- `/code-review` after implementation
- `/test-coverage` to verify coverage
