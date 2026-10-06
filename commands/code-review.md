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
   file:line and a suggested fix
5. Block commit if CRITICAL or HIGH issues are found
