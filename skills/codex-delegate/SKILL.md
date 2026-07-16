---
name: codex-delegate
description: Claude が司令塔（設計・タスク分割・監査）、Codex が実行部隊（実装・テスト実行・環境構築）を担うハイブリッド開発ワークフロー。設計・仕様が固まった実装タスク、複数ファイルにまたがる新規実装、並列化できる独立タスク群を依頼されたとき（グローバル CLAUDE.md のルーティング方針）、Codex への委譲を明示されたとき、/codex-impl が呼ばれたときに使用。小規模修正・デバッグ・リファクタは Claude が直接行うため使用しない。
---

# Codex Delegate — ハイブリッド役割分担

Claude Code（司令塔）が設計と監査を行い、OpenAI Codex CLI（実行部隊）に実装を委譲するワークフロー。

理想の入力は [[codex-spec]] で作った設計書（ユニット分割・受け入れ条件・境界が明記済み）。その場合は分割し直さず、各ユニットをそのまま委譲する。設計書が無い場合はこのスキル内で分割する。

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
codex exec -s workspace-write -C <作業ディレクトリ> -o <最終メッセージ.md> "<タスク>" > <進捗ログ.log> 2>&1
```

- 実装タスク: `-s workspace-write`（既定で使う）。調査・読み取りのみ: `-s read-only`。git repo 外: `--skip-git-repo-check`
- **background 実行を既定にする** — フォアグラウンドだと完了まで何も見えない。stdout（Codex の思考・実行コマンドの生ログ）を進捗ログへリダイレクトし、`-o` は完了検知と結果回収に使う
- **開始時に進捗ログのパスをユーザーへ伝える** — 別ターミナルで `tail -f <進捗ログ>` すれば生ログを追える
- 実行中は適宜ログ末尾を読み、進捗（いま何をしているか・エラーの兆候）を短く報告する
- **完了後ハングに注意**: codex exec は task_complete 後もプロセスが終了しないことがある。`-o` の最終メッセージファイルが書かれていたら完了とみなし、残プロセスは kill して先へ進む（成果物・セッションログはディスクに永続済みなので安全）
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
# 各 worktree で background 実行（進捗ログ + 最終メッセージを分けて回収）
codex exec -s workspace-write -C ../<proj>-task1 -o /tmp/task1-last.md "<タスク1>" > /tmp/task1.log 2>&1 &
codex exec -s workspace-write -C ../<proj>-task2 -o /tmp/task2-last.md "<タスク2>" > /tmp/task2.log 2>&1 &
```

全タスク完了後、worktree ごとに監査 → merge → `git worktree remove`。

## 監査ループ（Claude の仕事、省略禁止）

1. **Codex の自己申告を信じない** — `git diff` を自分で読む
2. **テストを自分で実行する** — 受け入れ条件のコマンドを Claude 側で再実行
3. NG の場合は修正を再委譲:
   - 基本は新規 `codex exec`（前セッションの成果と修正指摘をプロンプトに含める）
   - `codex exec resume --last` は限定的に使う。**worktree 委譲では使用禁止** — resume は元セッションの `-C <dir>` を引き継がず**シェルの cwd で実行される**ため、メインの作業ツリーに別実装を書き込んで汚染する（codex-cli 0.144.2 で確認）。また並列委譲中は `--last` がどのセッションを指すか不定
   - 汚染してしまった場合の復旧: `git checkout -- <誤変更ファイル>` + 未追跡の誤生成物を削除（正は worktree 側にある前提で消してよいか diff 確認してから）
4. 2〜3 回の再委譲で収束しなければ、Claude が直接引き取って修正する
5. OK になったら commit（コミットは Claude が行う。Codex にはさせない）

## 報告

委譲が終わったら以下をまとめて報告する:

- 委譲したタスクと結果（成功/再委譲回数/引き取り）
- 監査で見つけた問題と対処
- 残課題
