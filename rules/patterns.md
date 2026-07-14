# Common Patterns

## API Response Format (team contract)

```typescript
interface ApiResponse<T> {
  success: boolean
  data?: T
  error?: string
  meta?: { total: number; page: number; limit: number }
}
```

## Skeleton Projects

When implementing new functionality:
1. Search for battle-tested skeleton projects
2. Evaluate options with parallel agents (security, extensibility, relevance)
3. Clone the best match as foundation and iterate within the proven structure
