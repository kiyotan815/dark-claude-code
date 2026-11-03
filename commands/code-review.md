---
description: Review uncommitted changes with the dcc:code-reviewer agent; escalate security-sensitive diffs to security-reviewer.
---

# Code Review

Review the current uncommitted changes:

1. Get changed files: `git diff --name-only HEAD`
2. Invoke the **code-reviewer** agent on the changed files
   (quality, error handling, conventions — its checklist is the single source)
3. If the diff touches user input, auth, API endpoints, or secrets,
   also invoke the **security-reviewer** agent
4. Report findings by severity (CRITICAL / HIGH / MEDIUM / LOW) with
   file:line, a suggested fix, and the agent's Verdict / Evidence /
   Missing evidence. Keep `unresolved` findings in the list with the
   evidence they lack
5. Block commit if CRITICAL or HIGH issues are `verified`. For an
   `unresolved` CRITICAL / HIGH, run the test or command named in
   Missing evidence before deciding
6. After fixing CRITICAL / HIGH, re-run the code-reviewer (and the
   security-reviewer if it ran) on the fixed files only, and check the
   callers and tests of the changed code. Repeat until no CRITICAL / HIGH
   remain
