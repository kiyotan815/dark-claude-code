---
description: 現在のメモリ内容を読みやすく一覧表示する（read-only）
---

Display the current state of the user's persistent memory in a scannable format. This command is read-only — do NOT write to any memory file.

## Step 1: Load

Read the memory directory listed in your system prompt:
1. Read `MEMORY.md`
2. Read every memory file referenced in the index

If the memory system is empty, say so and exit.

## Step 2: Format as a summary

Present the memory as a structured overview. Use this layout (in Japanese for explanatory parts):

```
# メモリ概要

📁 ディレクトリ: <path>
📊 合計: <N> ファイル / 約 <M> 文字

---

## 📌 MEMORY.md (索引)

<reproduce the contents of MEMORY.md verbatim>

---

## 📄 個別エントリ

### <icon> <filename.md>
**<name from frontmatter>** (type: <type>)

<description from frontmatter>

要点:
- <key point 1 extracted from body>
- <key point 2>
- <if feedback/project: short paraphrase of the Why>

---

(repeat for each file)
```

Type icons:
- 👤 user
- 🎯 feedback
- 🚧 project
- 🔗 reference

## Step 3: Health flags (light touch only)

After the listing, add:

```
## 🩺 健全性チェック

- ✅ MEMORY.md 行数: <N> / 200 (上限)
- ✅ すべての索引エントリに対応ファイル
- ⚠️  古い可能性: <entries with clearly stale signals — past dates, "scheduled for X" where X has passed>
```

Only flag items with **clear** staleness signals. Do not deep-audit — that's `/memory-clean`'s job. If nothing is suspicious, write `- ✅ 古さの明確なシグナルなし`.

## Step 4: Done

No modifications. No file writes. Just the summary.
