---
name: ruby-patterns
description: Use when writing or reviewing Ruby code. Team conventions: Ruby 3.x baseline, community style guide + rubocop, frozen string literals.
---

# Ruby Patterns

Team conventions for Ruby (Rails, Sinatra, plain Ruby). Assumes fluency in idiomatic Ruby — records decisions, not syntax.

## Baseline

- **Ruby 3.x** — use modern features (pattern matching, hash shorthand `{ name:, age: }`) where they aid clarity.
- Endless methods only for true one-liners; numbered block params (`_1`) only with a single parameter.
- `# frozen_string_literal: true` at the top of every file.

## Style

- Follow the community [Ruby Style Guide](https://rubystyle.guide/).
- Enforce with `rubocop`; the `standard` gem is acceptable for less-bikeshed config.
- Target methods under ~10 lines; extract when longer.

## Conventions

- Blocks/Enumerable over `for` loops; symbols for identifiers.
- Explicit `return` only for early returns.
- `rescue StandardError` (never `Exception`); project exception hierarchies under `StandardError`; `ensure` for cleanup.
- Be deliberate about bang (`!`) mutators vs non-mutating variants.
- Hash keys: pick symbols or strings per codebase and stay consistent (Rails: `HashWithIndifferentAccess` where mixing is unavoidable).
