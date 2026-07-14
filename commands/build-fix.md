---
description: Fix build and type errors incrementally via the build-error-resolver agent. Minimal diffs, one error at a time.
---

# Build and Fix

Invoke the **build-error-resolver** agent to get the build green:

1. Run build: `npm run build` or `pnpm build`
2. Parse error output: group by file, sort by severity
3. For each error: show context, explain, propose fix, apply, re-run build
4. Stop if a fix introduces new errors, the same error persists after
   3 attempts, or the user requests pause
5. Show summary: fixed / remaining / newly introduced

Fix one error at a time. Minimal diffs only — no architectural changes
(that is the agent's contract).
