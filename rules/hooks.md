# Hooks System

Hooks live in `settings.json` — project (`.claude/settings.json`) or
user-global (`~/.claude/settings.json`). dark-claude-code ships a reference
set in `hooks/hooks.json` (copy/merge manually; scripts deploy to
`.claude/scripts/hooks/` via `dcc sync`).

## Shipped Reference Hooks

- **PreToolUse**: tmux reminder for long commands; dev-server-outside-tmux
  blocker; git push review reminder; stray .md/.txt doc blocker
- **PostToolUse**: PR URL logging; Prettier auto-format; tsc check;
  console.log warning
- **Stop / SessionEnd**: console.log audit; session state persistence
- **Learning system** (user-global settings): observation hooks + observer
  auto-start — see `skills/continuous-learning-v2`

## Auto-Accept Permissions

- Enable acceptEdits only for trusted, well-defined plans
- Never use the dangerously-skip-permissions flag; prefer scoped
  `permissions.allow` rules
