---
name: coding-standards
description: Use when writing or reviewing TS/JS/React/Node code. Team conventions: directory layout, file naming, ApiResponse/zod error shape, JSDoc, query rules.
---

# Coding Standards (Team-Specific)

General principles (KISS/DRY/YAGNI, naming) are assumed knowledge; immutability,
error handling, zod validation, and size limits live in `rules/coding-style.md`.
Do not restate any of them — this skill only adds team conventions.

## Project Structure

```
src/
├── app/          # Next.js App Router (api/, route groups)
├── components/   # ui/, forms/, layouts/
├── hooks/        # Custom React hooks
├── lib/          # api/, utils/, constants/
├── types/        # TypeScript types
└── styles/       # Global styles
```

## File Naming

- `components/Button.tsx` — PascalCase for components
- `hooks/useAuth.ts` — camelCase with `use` prefix
- `lib/formatDate.ts` — camelCase for utilities
- `types/market.types.ts` — `.types.ts` suffix for type files

## Team Conventions

- API responses use the shared `ApiResponse<T>` shape (rules/patterns.md);
  error responses are `{ success: false, error }` with a proper HTTP status.
- On `ZodError`, return 400 with `error: 'Validation failed'` and
  `details: error.errors`.
- JSDoc required on exported public functions: params, returns, throws, example.
- DB queries: select explicit columns (never `select('*')`), always set a limit.
- Tests: AAA structure, behavior-describing names
  (e.g. "falls back to substring search when Redis unavailable").
