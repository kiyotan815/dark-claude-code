---
description: Generate and run end-to-end tests via the e2e-runner agent (Vercel Agent Browser preferred, Playwright fallback). Captures screenshots/videos/traces.
---

# E2E Command

Invoke the **e2e-runner** agent to generate, maintain, and execute
end-to-end tests for: `$ARGUMENTS`

## Workflow

1. **Analyze the user flow** and identify test scenarios
2. **Generate the test journey** (Vercel Agent Browser preferred;
   Playwright with Page Object Model as fallback — the agent decides)
3. **Run tests** across target browsers
4. **Capture artifacts** on failure: screenshots, videos, traces
5. **Report** results; quarantine flaky tests and recommend fixes

## When to Use

- Critical user journeys (login, checkout, payments)
- Multi-step flows that must work end-to-end
- Pre-deployment validation

## Rules

- Tooling choices, wait strategies (no fixed timeouts), and artifact
  handling are defined in the e2e-runner agent — do not duplicate them here
- Flaky tests are quarantined, not deleted
