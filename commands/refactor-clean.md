---
description: Find and remove dead code safely via the refactor-cleaner agent (knip / depcheck / ts-prune, test-verified deletions).
---

# Refactor Clean

Invoke the **refactor-cleaner** agent to identify and remove dead code:

1. Run analysis tools: `knip` (unused exports/files), `depcheck`
   (unused dependencies), `ts-prune` (unused TS exports)
2. Write the report to `.reports/dead-code-analysis.md`
3. Categorize: SAFE (tests, unused utilities) / CAUTION (API routes,
   components) / DANGER (config, entry points)
4. Propose SAFE deletions only
5. For each deletion: run tests → apply → re-run tests → rollback on failure

Never delete code without a passing test run before and after.
