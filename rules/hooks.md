# Hooks System

Hooks live in `settings.json` — project (`.claude/settings.json`) or
user-global (`~/.claude/settings.json`). The kit ships no always-on hooks.

`hooks/check-sensitive-paths.sh` is opt-in: copy it into a project's
`.claude/hooks/` and register it under `PreToolUse` with matcher
`Bash|Read|Edit|Write`. It blocks parent-directory, home-directory, and
non-origin git access for that project. It needs `jq`; without it, or on
unreadable input, it fails closed and blocks every call. Register it with
`${CLAUDE_PROJECT_DIR}` in the path and `"onFailure": "block"` (see the
README); without `onFailure`, a missing, non-executable, or timed-out hook
lets the call through.

Prefer the built-in Bash sandbox and `permissions.allow` / `deny` rules over
custom hooks for access control. Add a hook only for a deterministic,
project-specific check (lint on save, schema regeneration).

`Read` / `Edit` deny rules cover the file tools, `cat` / `head` / `tail` /
`sed` / `tee`, and redirections in Bash. They do not cover commands that
read files without naming them (`grep -r`) or node / python scripts that open
files themselves; the Bash sandbox is the enforcement for that. The kit's
settings template does not enable the sandbox: turn it on with `/sandbox`.

## Auto-Accept Permissions

- Enable acceptEdits only for trusted, well-defined plans
- Never use the dangerously-skip-permissions flag; prefer scoped
  `permissions.allow` rules
