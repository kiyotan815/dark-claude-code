---
description: メモリ内の古くなった/重複した/誤った情報を監査し、剪定提案を出す
---

You are auditing the user's persistent memory for staleness. Follow this process exactly.

## Step 1: Load all memory

Read the memory directory listed in your system prompt:
1. Read `MEMORY.md`
2. Read every `.md` file in the memory directory

If the memory system is empty, report that and exit.

## Step 2: Audit each entry against current reality

For each memory file, check these failure modes:

**Stale references** — does the file/function/path mentioned still exist?
- If a memory says "X is in lib/foo.ts", verify it. Use `ls`, `grep`, or `Read`. Verify, don't assume.

**Time-bound items past relevance**
- Specific dates that have passed (e.g., "release scheduled YYYY-MM-DD" — did it happen?)
- Phase markers that may have advanced
- Bug workarounds whose underlying bug may be fixed (web search briefly if relevant)

**Contradicted by current code**
- e.g., "we use Model A" but the code now imports Model B

**Duplicates across files** — same fact restated in multiple memory files → consolidate

**Vague / unactionable** — no clear Why or How to apply → sharpen or remove

**MEMORY.md hygiene**
- Every file in the directory listed in the index?
- Every index entry points to an existing file?
- Total lines under 200?

## Step 3: Present findings

Output in Japanese:

```
メモリ監査結果:

【削除推奨】（情報が古い/不正確）
1. <file.md> の "<entry>"
   現状: <quote>
   理由: <verification result>

【更新推奨】（部分的に古い）
2. <file.md> の <section>
   現状: <quote>
   提案: <new text>
   理由: <evidence>

【統合推奨】（重複）
3. <fileA.md> と <fileB.md> の <topic> が重複
   → <destination> に集約することを推奨

【MEMORY.md 整合性】
4. <issue if any>

【健全 — 変更不要】
- <list of files that passed audit>

どの変更を適用しますか? 番号で指定 (例: 1,2 / all / none)
```

## Step 4: Wait for confirmation

Do NOT modify files until the user responds.

## Step 5: Apply changes

- **Delete**: remove the file AND remove its line from MEMORY.md
- **Update**: edit in place, update `description` frontmatter if focus has shifted
- **Consolidate**: move content to destination, delete source, update MEMORY.md

After all changes, verify MEMORY.md is still under 200 lines and every link points to an existing file.

## Step 6: Report

Summarize what was deleted, updated, or merged. Note declined items so the user can reconsider later.

## Cautious operation

- Never delete without explicit user confirmation.
- If verification is ambiguous, report the uncertainty rather than guessing.
- When in doubt, propose updating rather than deleting.
