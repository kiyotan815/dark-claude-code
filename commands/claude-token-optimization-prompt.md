# Claude Code Token Optimization Prompt

Copy to `~/.claude/commands/optimize-tokens.md` for global use as `/optimize-tokens`,
or paste directly into any Claude Code conversation.

---

## Prompt

```
このリポジトリのClaude Codeトークン消費を調査・削減してください。

## 調査対象

以下を順番に確認し、それぞれの行数と問題点を報告してください:

1. **CLAUDE.md** - 80行以下が目標。コード例やClaudeが既に知っている情報（一般的なパターン、エラーハンドリング例等）は不要
2. **.claude/rules/*.md** - 毎会話で全て読み込まれる。CLAUDE.mdとの重複、Claudeが既に知っている情報（エージェント一覧、フック説明、モデル選択ガイド等）を特定
3. **.claudeignore** - 存在するか確認。node_modules, lock files, build artifacts, .next, dist, coverage等が除外されているか
4. **.claude/skills/*.md** - テンプレートや汎用パターン集（このプロジェクト固有でないもの）を特定
5. **.claude/examples/, .claude/plugins/, .claude/README.md, .claude/CONTRIBUTING.md** - テンプレートリポジトリの残骸がないか
6. **PostToolUseフック** - settings.jsonでtsc等の重いチェックが毎Edit実行になっていないか
7. **大きなドキュメント** - docs/内の大きなファイルでコーディングに不要なもの

## 削減ルール

- CLAUDE.md + rulesの合計は100行以下を目指す
- コード例は全て削除（Claudeは一般的なパターンを既に知っている）
- 1行の箇条書きで十分伝わるものは箇条書きにする
- 以下はルールに書く必要がない:
  - エージェントの使い方（システムプロンプトに含まれる）
  - フックの説明（settings.jsonを直接読める）
  - モデル選択ガイド（Claude自身が判断できる）
  - 汎用パターン（Repository, useDebounce, ErrorBoundary等）
- .claudeignoreに追加すべきもの: lock files, build artifacts, テンプレートファイル, コーディングに不要な大きなドキュメント

## 実施手順

1. まず調査結果を表形式で報告（ファイル名、行数、問題点、対策）
2. 確認を待たずに実施:
   - .claudeignoreの作成/更新
   - CLAUDE.mdの簡潔化（プロジェクト固有の情報のみ残す）
   - rulesファイルの統合・削除（重要なルールはCLAUDE.mdに統合）
   - テンプレート/汎用ファイルの削除（git rm）
3. Before/Afterの行数比較を報告
4. settings.jsonのフック最適化が必要な場合は、具体的な変更内容を提示（手動対応）
```
