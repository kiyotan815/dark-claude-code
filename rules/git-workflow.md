# Git Workflow

## Commit Message Format

```
<type>: <description>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci.
Attribution is disabled globally via ~/.claude/settings.json.

## Pull Request Workflow

1. Analyze the full commit history, not just the latest commit
   (`git diff [base-branch]...HEAD`)
2. Draft a comprehensive PR summary with a test plan
3. Push with `-u` for new branches

## Feature Implementation Flow

**planner** (plan/phases) → **tdd-guide** (tests first) →
**code-reviewer** (fix CRITICAL/HIGH) → commit with conventional format
