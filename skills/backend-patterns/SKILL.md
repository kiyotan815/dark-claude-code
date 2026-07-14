---
name: backend-patterns
description: Use when writing Node/Express/Next.js API routes, data access, or auth — ApiError handling, cache TTL, rate-limit/retry thresholds, logging format.
---

# Backend Patterns (Team-Specific)

General REST/layering knowledge is assumed. `ApiResponse<T>` and the
Repository interface live in rules/patterns.md — use them as-is.

## Architecture

- Data access behind Repository interfaces; business logic in Service classes
  receiving repositories via constructor injection.
- Auth/permissions as HOF middleware wrapping route handlers
  (`withAuth(handler)`, `requirePermission('delete')(handler)`).
- Multi-table writes go through a Supabase RPC (plpgsql function) —
  never client-side multi-step writes.
- Roles: `admin` / `moderator` / `user`; permissions admin: all,
  moderator: read+write+delete, user: read+write.

## Error Handling

- Throw `ApiError(statusCode, message, isOperational)`; one central
  `errorHandler` maps ApiError → its status, ZodError → 400 with `details`,
  everything else → logged + generic 500. Route handlers try/catch and delegate.
- Never leak internal error details in 500 responses.

## Thresholds & Defaults

- Cache: Redis cache-aside, key `<entity>:<id>`, TTL 300s, invalidate on write.
- Rate limit: 100 requests/min per IP, respond 429 when exceeded.
- Retry: max 3 attempts, exponential backoff 1s/2s/4s.
- Queries: explicit column lists, batch-fetch to avoid N+1, always `.limit()`.

## Logging & Jobs

- Structured JSON logs: `{ timestamp, level, message, requestId, ...context }`;
  generate a `requestId` per request; log errors with message + stack.
- Slow work: enqueue a background job and return immediately
  (`{ success: true, message: 'Job queued' }`) instead of blocking.
