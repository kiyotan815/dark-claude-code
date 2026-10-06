---
description: Restate requirements, assess risks, and create a step-by-step implementation plan. WAIT for user CONFIRM before touching any code.
---

# Plan

Produce an implementation plan for `$ARGUMENTS` and stop. Do not write code
until the user confirms.

1. **Restate requirements** in your own words and list open questions.
2. **Read the code**: use the built-in `Plan` agent (or Plan Mode) to map
   affected files, dependencies, and existing patterns.
3. **Phases**: break the work into ordered phases with concrete files per
   phase; mark what can run in parallel.
4. **Risks**: HIGH / MEDIUM / LOW with a mitigation each; call out anything
   that needs a migration, a feature flag, or a rollback plan.
5. **Complexity**: one line per phase (High / Medium / Low).
6. End with `**WAITING FOR CONFIRMATION**: proceed? (yes / modify: ... /
   different approach: ...)` and stop.

If the work is a multi-file implementation suited to Codex delegation, write
the plan as a `/dcc:codex-spec` design doc instead, and hand off to
`/dcc:codex-impl` after confirmation.
