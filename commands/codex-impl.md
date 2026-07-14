---
description: 設計書またはタスクを codex exec に委譲し、Claude が git diff とテスト再実行で監査するまでを一括実行（codex-delegate skill 準拠）。
---

# Codex Implement

$ARGUMENTS で渡された設計書（ファイルパス）またはタスク説明を、Codex に委譲して実装する。

手順:

1. **codex-delegate skill を使用する**（委譲の作法・監査ループはすべて skill に従う）
2. 設計書 / タスクを読み、独立した実装単位に分割する
3. 分割結果と委譲計画（並列にするか、順次か）を短く提示してから実行する
4. 各タスクを `codex exec` で委譲する（競合しない場合は worktree で並列）
5. 成果物を監査する — **codex-auditor agent** を使う（境界逸脱の検出・受け入れ条件との突合・テストの再実行・並列ユニット間の整合確認）。FIX REQUIRED なら auditor が書いた再委譲プロンプトで再委譲
6. 委譲結果・監査所見・残課題を報告する

注意:

- 設計が曖昧なまま委譲しない。分割できないほど要件が不明瞭なら、先に設計を固めることを提案する
- commit は監査完了後に Claude が行う
