---
description: 直近の会話を振り返り、メモリに保存すべき情報を抽出・提案する
---

You are reviewing the current conversation and proposing updates to the user's persistent memory system. Follow this process exactly.

## Step 1: Inventory existing memory

Read the memory directory listed in your system prompt (under "auto memory" / "memory system at ..."):
1. Read `MEMORY.md` (the index)
2. Read every memory file referenced in the index

If the memory directory doesn't exist yet, note that and proceed — this will be the first save.

## Step 2: Scan the conversation for memory-worthy content

Review the entire current conversation and identify candidates in these four categories:

- **user**: Who the user is — role, responsibilities, preferences, knowledge level
- **feedback**: How to work — what to do/avoid, with the *reason* (drives edge-case judgment)
- **project**: Strategic decisions, deadlines, stakeholder context — the *why* behind the work
- **reference**: Pointers to external systems / files where information lives

## Step 3: Filter out noise

Do NOT propose saving:
- Code patterns, file paths, function names (derivable from the codebase)
- "What changed in this session" (commit territory)
- Ephemeral task state, current to-dos (TodoList territory)
- Information already in CLAUDE.md files
- Frequently-changing values like API rate-card numbers (project docs territory)
- Duplicates of existing memory (unless this is an *update*)

If something is interesting but better suited to a project doc or commit, say so rather than memorizing it.

## Step 4: Present candidates

Output a numbered list grouped by action type, in Japanese:

```
直近の会話から以下の保存候補を抽出しました:

【新規追加】
1. [type: project] 「<title>」 — <one-line description>
   → 新規ファイル <filename>.md として作成

【既存メモの更新】
2. [file: project_overview.md] 〜セクションを最新化
   現状: <quote>
   提案: <new text>

【スキップ推奨】
3. <topic> — <reason>（例: コードで grep できるためメモ不要）

この方針で保存しますか? 番号で指定 (例: 1,2 / all / none)
```

## Step 5: Wait for confirmation

Do NOT write any file until the user responds with their selection.

## Step 6: Apply the changes

For each accepted item:

**New entries** — create `<filename>.md` with this format:
```markdown
---
name: <Short title>
description: <one-line description, used for relevance matching in future conversations — be specific>
type: <user|feedback|project|reference>
---

<body>
```
For `feedback` and `project` types, structure the body as: rule/fact, then `**Why:**` and `**How to apply:**` lines.

**Updates** — edit in place. Update `description` frontmatter if focus has shifted.

**MEMORY.md** — add one line per new file in the format `- [Title](filename.md) — one-line hook`. Keep entries under ~150 characters. The index file holds links only, never memory content.

## Step 7: Report

Briefly confirm what was saved/updated.

## Quality gates

- Each memory file should be focused on one topic. If a candidate spans multiple topics, propose splitting it.
- The `description` field is what future-Claude reads to judge relevance — make it specific.
- For `feedback`/`project` entries, the `**Why:**` line is critical — a rule without its reason can't be applied to edge cases.
- Keep MEMORY.md under 200 lines total.
