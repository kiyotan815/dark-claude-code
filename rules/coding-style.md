# Coding Style

- **Immutability (CRITICAL)**: always create new objects (spread, `map`/`filter`);
  never mutate function arguments or shared state
- **File organization**: many small files > few large ones; 200-400 lines typical,
  800 max; organize by feature/domain, not by type
- **Error handling**: wrap risky operations, log with context, rethrow a
  user-friendly message; never swallow errors
- **Input validation**: validate all external input at the boundary (zod for TS)

## Quality Checklist (before marking work complete)

- [ ] Readable, well-named code
- [ ] Functions < 50 lines, nesting < 4 levels
- [ ] Proper error handling; no console.log
- [ ] No hardcoded values or secrets
- [ ] No mutation
