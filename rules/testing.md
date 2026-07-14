# Testing Requirements

## Minimum Test Coverage: 80%

Test types (ALL required):
1. **Unit** - functions, utilities, components
2. **Integration** - API endpoints, database operations
3. **E2E** - critical user flows (e2e-runner agent)

TDD is mandatory — the workflow is defined in the global CLAUDE.md
(RED → GREEN → REFACTOR); use the **tdd-guide** agent to enforce it.

## Troubleshooting Test Failures

1. Check test isolation and mocks
2. Fix the implementation, not the tests (unless the test is wrong)
