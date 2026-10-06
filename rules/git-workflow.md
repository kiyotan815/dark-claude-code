# Git Workflow

## Commit Message Format

```
<type>: <description>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci.
Attribution is disabled globally via ~/.claude/settings.json.

Before every commit, run type check, tests, and lint as one chained command
(e.g. `npx tsc --noEmit && npm test && npm run lint`) and commit only when
all pass.

## Pull Request Workflow

1. Analyze the full commit history, not just the latest commit
   (`git log --oneline [base-branch]..HEAD` and
   `git diff --stat [base-branch]...HEAD`)
2. Draft a comprehensive PR summary with a test plan
3. Push with `-u` for new branches

## Feature Implementation Flow

Plan Mode (phases) → tests first (`dcc:tdd-workflow` skill) →
**dcc:code-reviewer** (fix CRITICAL/HIGH) → commit with conventional format
