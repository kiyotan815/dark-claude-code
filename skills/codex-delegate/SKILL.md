---
name: codex-delegate
description: Claude が司令塔（設計・タスク分割・監査）、Codex が実行部隊（実装・テスト実行・環境構築）を担うハイブリッド開発ワークフロー。設計・仕様が固まった実装タスク、複数ファイルにまたがる新規実装、並列化できる独立タスク群を依頼されたとき（グローバル CLAUDE.md のルーティング方針）、Codex への委譲を明示されたとき、/codex-impl が呼ばれたときに使用。小規模修正・デバッグ・リファクタは Claude が直接行うため使用しない。
---

# Codex Delegate — ハイブリッド役割分担

Claude Code（司令塔）が設計と監査を行い、OpenAI Codex CLI（実行部隊）に実装を委譲するワークフロー。

## 役割分担

| 担当 | 仕事 |
|---|---|
| Claude（このセッション） | 設計、依存関係の整理、タスク分割、委譲プロンプト作成、成果物の監査（diff レビュー・テスト実行・修正指示）、commit |
| Codex（`codex exec`） | 委譲されたタスクの実装、テストの実行と修正、環境構築などのターミナル作業 |

## 前提チェック（委譲前に1回）

1. `command -v codex` — 無ければ中止して報告（devcontainer なら postCreate 済みのはず）
2. 認証 — `~/.codex/auth.json` があるか `OPENAI_API_KEY` が設定されていること。無ければ README の認証手順を案内して中止

## 委譲の基本形

```bash
codex exec -s workspace-write -C <作業ディレクトリ> -o <ログファイル> "<タスク>"
```

- 実装タスク: `-s workspace-write`（既定で使う）
- 調査・読み取りのみ: `-s read-only`
- git repo 外での作業: `--skip-git-repo-check`
- 長いタスクは Bash の background 実行にし、`-o` の最終メッセージで完了を検知する
- `--dangerously-bypass-approvals-and-sandbox` は使わない

## 委譲プロンプトの書き方（品質はここで決まる）

1. **成果物を1つに絞る** — 「〜が実装され、`<テストコマンド>` が通る状態」
2. **受け入れ条件を明記** — 実行すべきテストコマンドと期待結果
3. **境界を明記** — 触ってよいファイル/ディレクトリ、触ってはいけないもの
4. プロジェクト方針（言語・TDD 等）は `AGENTS.md` が伝えるので繰り返さない
5. 巨大タスクを1回で丸投げしない — 独立した単位に分割する

## 並列実装（git worktree 方式）

ファイル競合しない独立タスクに分割できる場合のみ並列化する。

```bash
git worktree add ../<proj>-task1 -b codex/task1
git worktree add ../<proj>-task2 -b codex/task2
# 各 worktree で background 実行
codex exec -s workspace-write -C ../<proj>-task1 -o /tmp/task1.md "<タスク1>" &
codex exec -s workspace-write -C ../<proj>-task2 -o /tmp/task2.md "<タスク2>" &
```

全タスク完了後、worktree ごとに監査 → merge → `git worktree remove`。

## 監査ループ（Claude の仕事、省略禁止）

1. **Codex の自己申告を信じない** — `git diff` を自分で読む
2. **テストを自分で実行する** — 受け入れ条件のコマンドを Claude 側で再実行
3. NG の場合は修正を再委譲:
   - 同一セッション継続: `codex exec resume --last "修正: <具体的な指摘>"`
   - 文脈を変えたい場合は新規 `codex exec`
4. 2〜3 回の再委譲で収束しなければ、Claude が直接引き取って修正する
5. OK になったら commit（コミットは Claude が行う。Codex にはさせない）

## 報告

委譲が終わったら以下をまとめて報告する:

- 委譲したタスクと結果（成功/再委譲回数/引き取り）
- 監査で見つけた問題と対処
- 残課題
