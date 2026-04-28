# Issue Implementation Flow

Automated spec generation for GitHub Issue #$ARGUMENTS.
All user-facing output in Japanese.

## Phase 1: Read Issue

```
gh issue view $ARGUMENTS --json title,body,labels,comments,assignees,milestone
```

Read referenced files/documents if any.

## Phase 2: 3-Agent Spec Proposals

Launch 3 agents **in parallel** with the Agent tool. Pass full issue text to each.
Investigation scope: issue-mentioned files + max 5 related files + relevant DB tables only.

| Agent | subagent_type | Role |
|-------|---------------|------|
| A | `spec-pragmatic` | MVP-focused pragmatic proposal |
| B | `spec-architect` | Extensibility/design-focused proposal |
| C | `spec-ux` | UX/user-experience-focused proposal |

## Phase 3: Present and Select

Show 3 proposals with comparison table (工数/拡張性/UX品質/リスク).
AskUserQuestion: "どの提案を採用しますか？（A / B / C / ミックス指定も可）"

## Phase 4: Post to Issue

Post finalized spec as issue comment via `gh issue comment $ARGUMENTS --body "..."`.
Include: 採用アプローチ, スコープ, 技術設計, 実装ステップ(TDD), 受け入れ基準.

## Phase 5: Next Action

AskUserQuestion: "1. 実装に進む 2. 一旦終了"
If 1: `git checkout -b feature/issue-$ARGUMENTS` and start TDD.
