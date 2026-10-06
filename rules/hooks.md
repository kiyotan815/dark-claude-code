# Hooks System

Hooks live in `settings.json` — project (`.claude/settings.json`) or
user-global (`~/.claude/settings.json`). The kit ships no always-on hooks.

`hooks/check-sensitive-paths.sh` is opt-in: copy it into a project's
`.claude/hooks/` and register it under `PreToolUse` with matcher
`Bash|Read|Edit|Write`. It blocks parent-directory, home-directory, and
non-origin git access for that project.

Prefer the built-in Bash sandbox and `permissions.allow` / `deny` rules over
custom hooks for access control. Add a hook only for a deterministic,
project-specific check (lint on save, schema regeneration).

## Auto-Accept Permissions

- Enable acceptEdits only for trusted, well-defined plans
- Never use the dangerously-skip-permissions flag; prefer scoped
  `permissions.allow` rules
