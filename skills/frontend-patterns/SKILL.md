---
name: frontend-patterns
description: Use when building React/Next.js components, hooks, or client data fetching — framer-motion, react-virtual, lazy-loading, ErrorBoundary/form rules.
---

# Frontend Patterns (Team-Specific)

Standard React knowledge (composition, hooks, memoization, a11y, error
boundaries) is assumed — this file only records team choices and thresholds.
The `useDebounce` reference implementation lives in rules/patterns.md.

## Library Choices

- Animations: framer-motion (`AnimatePresence` for list/modal enter-exit).
- Long lists: virtualize with `@tanstack/react-virtual` (overscan: 5).
- Client data fetching: shared `useQuery`-style hook returning
  `{ data, error, loading, refetch }` with `onSuccess`/`onError` options.

## Requirements

- Lazy-load heavy components (charts, 3D backgrounds) via `lazy()` +
  `Suspense` with a skeleton fallback.
- Wrap the app root (and risky feature subtrees) in an ErrorBoundary that
  offers a retry action.
- Search inputs: debounce 500ms before firing queries.
- Forms: controlled components, validate client-side before submit,
  per-field error messages mirroring the API zod schema.
- State derived from previous state: functional updates only
  (`setX(prev => ...)`).
- Context consumer hooks must throw if used outside their Provider.
- Modals: save/restore focus, `role="dialog"` + `aria-modal`, close on Escape.
