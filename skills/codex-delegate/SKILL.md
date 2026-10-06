---
name: codex-delegate
description: Claude が司令塔（設計・タスク分割・監査）、Codex が実行部隊（実装・テスト実行・環境構築）を担うハイブリッド開発ワークフロー。設計・仕様が固まった実装タスク、複数ファイルにまたがる新規実装、並列化できる独立タスク群を依頼されたとき（グローバル CLAUDE.md のルーティング方針）、Codex への委譲を明示されたとき、/dcc:codex-impl が呼ばれたときに使用。小規模修正・デバッグ・リファクタは Claude が直接行うため使用しない。
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
3. **Bash sandbox の制約** — Claude Code の Bash sandbox 内では `codex exec` が app-server 初期化で `Operation not permitted` になり、**exit 0 のまま進捗ログが 3 行程度で止まる**。ログが伸びないときは exit code を信用せず sandbox 起因と判断し、そのコマンドだけ sandbox 外で再実行する（permission ゲートを通す）。書き込み範囲は Codex 側の `-s workspace-write` が制限するので、Codex の `--dangerously-bypass-approvals-and-sandbox` は引き続き使わない
4. sandbox で `find` / `ls` が `Operation not permitted` になる場合は `git ls-files` / `git grep` に切り替える

## 委譲の基本形

```bash
S=<セッションの scratchpad ディレクトリ>   # /tmp ではなく scratchpad を使う
codex exec -s workspace-write -C <作業ディレクトリ> -o "$S/u1-last.md" \
  "$(cat "$S/u1-prompt.md")" < /dev/null > "$S/u1.log" 2>&1 &
```

- 実装タスク: `-s workspace-write`（既定で使う）。調査・読み取りのみ: `-s read-only`。git repo 外: `--skip-git-repo-check`
- **`< /dev/null` で stdin を閉じる** — 付けないと background 実行時に stdin 待ちでハングする
- **background 実行を既定にする** — stdout（Codex の思考・実行コマンドの生ログ）は進捗ログへ、`-o` の最終メッセージは完了検知と結果回収に使う
- **完了検知はブロッキング待機しない** — `until [ -f "$S/u1-last.md" ]; do sleep 5; done` を background で回し、タスク通知を待つ。待っている間に次ユニットのプロンプト準備や完了済みユニットの監査を進める
- **開始時に進捗ログのパスをユーザーへ伝える** — 別ターミナルで `tail -f <進捗ログ>` すれば生ログを追える。実行中は適宜ログ末尾を読み、進捗（いま何をしているか・エラーの兆候）を短く報告する
- **完了後ハングに注意**: codex exec は task_complete 後もプロセスが終了しないことがある。`-o` の最終メッセージファイルが書かれていたら完了とみなし、残プロセスは kill して先へ進む（成果物・セッションログはディスクに永続済みなので安全）
- **ネットワーク要因の失敗**（DNS・registry 到達不可など）は、仕様を変えずに `-c sandbox_workspace_write.network_access=true` を付けて同じユニットを再委譲する。コード起因の失敗と区別し、再委譲回数には数えない

## 委譲プロンプトの書き方（品質はここで決まる）

委譲を始める前に、**全ユニットのプロンプトを scratchpad に `uN-prompt.md` として書き出す**。`"$(cat ...)"` で渡し、インラインで書くなら `<<'EOF'`（クォート付き heredoc）を使う。バッククォートや `$()` の展開でプロンプトが壊れるのを防ぐため。

1. **成果物を1つに絞る** — 「〜が実装され、`<テストコマンド>` が通る状態」
2. **受け入れ条件を明記** — ユニット固有のテストファイルとコマンド、期待結果。「`npm test` が通る」のような全体指定は不可。並列実行中はフルスイートを回させない
3. **境界を明記**:
   - 触ってよいファイル / 触ってはいけないファイル
   - ファイル内の変更可能部分（例: 「`route.ts` の DELETE handler のみ」）
   - 型エラーの責任範囲（他ユニット起因は無視してよい）
   - 他ユニットのテストが未変更のまま落ちても無視する
   - `git commit` / `git push` はしない（commit は Claude が行う）
4. **TDD 厳守を冒頭に明記** — 「テスト追加 → 失敗確認 → 実装。実装中はテストを変更しない」。プロジェクト方針は `AGENTS.md` が伝えるので原則繰り返さないが、**TDD と境界だけは毎回書く**
5. 巨大タスクを1回で丸投げしない — 独立した単位に分割する

## 並列実装（git worktree 方式）

ファイル競合しない独立タスクに分割できる場合のみ並列化する。

```bash
# 設計書は worktree を作る前にベースブランチへ commit しておく（各 worktree から参照できる）
git worktree add ../<proj>-u1 -b codex/u1
git worktree add ../<proj>-u2 -b codex/u2
for w in ../<proj>-u1 ../<proj>-u2; do
  ln -s "$PWD/node_modules" "$w/node_modules"   # install を繰り返さない
  cp .env "$w/" 2>/dev/null || true
done
codex exec -s workspace-write -C ../<proj>-u1 -o "$S/u1-last.md" "$(cat "$S/u1-prompt.md")" < /dev/null > "$S/u1.log" 2>&1 &
sleep 3   # 同時初期化の資源競合を避けるため 2〜3 秒ずらして起動する
codex exec -s workspace-write -C ../<proj>-u2 -o "$S/u2-last.md" "$(cat "$S/u2-prompt.md")" < /dev/null > "$S/u2.log" 2>&1 &
```

**統合は監査 OK のユニットから 1 本ずつ**:

1. Claude が worktree 内で commit する
2. `git merge --no-ff codex/uN`
3. `git worktree remove ../<proj>-uN` と `git branch -d codex/uN`

全ユニットのマージ後、依存追加があれば install、コード生成（`prisma generate` 等）を再実行し、統合ブランチでフルテスト・tsc・lint を回す。

## 監査ループ（Claude の仕事、省略禁止）

0. **自己申告を集約してから始める** — 全ユニットの `-last.md` を順に読み、変更ファイル・テスト結果・残課題をまとめる。自己申告は「どこを見るか」の索引としてだけ使う
1. **Codex の自己申告を信じない** — `git diff --stat` で範囲を確かめてから、全文 diff を自分で読む
2. **テストを自分で実行する** — 受け入れ条件のコマンドを Claude 側で再実行する。`listen EPERM` など sandbox の IPC 制約で落ちた場合はコード失敗として扱わず、同じテスト集合を等価な直接実行（例: `node --import tsx --test '<glob>'`）で確認し、その旨を報告に書く。package.json やテスト設定は変更しない
3. NG の場合は修正を再委譲:
   - 基本は新規 `codex exec`（前セッションの成果と修正指摘をプロンプトに含める）
   - `codex exec resume --last` は限定的に使う。**worktree 委譲では使用禁止** — resume は元セッションの `-C <dir>` を引き継がず**シェルの cwd で実行される**ため、メインの作業ツリーに別実装を書き込んで汚染する（codex-cli 0.144.2 で確認）。また並列委譲中は `--last` がどのセッションを指すか不定
   - 汚染してしまった場合の復旧: `git checkout -- <誤変更ファイル>` + 未追跡の誤生成物を削除（正は worktree 側にある前提で消してよいか diff 確認してから）
4. 2〜3 回の再委譲で収束しなければ、Claude が直接引き取って修正する
5. OK になったら commit（コミットは Claude が行う。Codex にはさせない）

委譲中にユーザーの要件変更が入ったら、**先に設計書を更新**（日付付きのユーザー発言・変更理由・影響）し、再委譲プロンプトでは「設計書の◯◯節の更新済み記述に従う」と節を指定する。

## 報告

委譲が終わったら以下をまとめて報告する:

- 委譲したタスクと結果（成功/再委譲回数/引き取り）
- 監査で見つけた問題と対処
- 残課題
