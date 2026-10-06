# Performance Optimization

## Model and Effort

- Main session model and effort come from `~/.claude/settings.json`
  (`model`, `effortLevel`, `modelSettings`). Never pin a model version in
  prompts, commands, or agent files.
- Agent frontmatter uses `model: inherit`. Set `model: haiku` only for
  high-frequency, low-stakes workers.
- Raise effort (`/effort xhigh`) for architecture decisions and
  large-context analysis; lower it for mechanical edits.

## Context Window Management

- Locate with `grep -n` first and read only that range; never read a large
  file whole.
- Keep large refactors, multi-file features, and complex debugging out of
  the last 20% of the context window; `/compact` at phase boundaries.
- Single-file edits, docs updates, and simple bug fixes are
  context-insensitive.
- Delegate large fan-out work (audits, migrations across many files) to
  subagents or a Workflow so intermediate output stays out of the main
  context.

## Deep Reasoning

For complex tasks: enter Plan Mode, write the plan, and run critique rounds
with split role sub-agents before implementing.

## Build Troubleshooting

If build fails: read the error output, fix one error at a time, and verify
after each fix. Do not refactor while the build is red.
