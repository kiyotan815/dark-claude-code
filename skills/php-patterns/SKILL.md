---
name: php-patterns
description: Use when writing or reviewing PHP code (any framework). Team conventions: PHP 8.1+ baseline, PSR-12, strict_types, static analysis tooling.
---

# PHP Patterns

Team conventions for PHP. Assumes fluency in modern PHP — this file records our decisions, not syntax.

## Baseline

- **PHP 8.1+** — prefer modern features (enums, readonly, constructor promotion, match, never) over legacy equivalents.
- `declare(strict_types=1)` as the first statement of every file.
- Comply with **PSR-1 / PSR-4 / PSR-12**. Enforce via `php-cs-fixer` or `phpcs`; pick a config, don't bikeshed.

## Strictness Rules

- Type every parameter, return, and property. No untyped signatures.
- Always `===` / `!==` — never loose comparison.
- Prefer `match` over `switch`, enums over string/int constants, `DateTimeImmutable` over `DateTime`.
- Value objects: `final readonly` classes validating at construction. Pass `Email`, not `string`.
- Classes `final` by default; interfaces at boundaries (clock, HTTP, payment) for injectability.
- Store times in UTC; never assume server timezone.

## Error Handling

- Project-specific exception hierarchies rooted in `RuntimeException`.
- Never catch `\Throwable` outside a top-level handler.

## Security

- Mass assignment: explicit allow-lists only (`$request->only([...])`), never `$request->all()`.

## Required Tooling

- `composer` with PSR-4 autoloading.
- `phpstan` (max level) or `psalm` (level 1) — must run in CI.
- `php-cs-fixer` / `phpcs` for style; `rector` for automated upgrades.
