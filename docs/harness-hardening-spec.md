# 長時間タスク向けハーネス強化 設計書

## 概要 / 背景

2026-11-04 の差分レポート（Opus 5.5 向け長時間タスク用ハーネス記事の 9 項目とこのキットの比較）で採用価値「高」とした 3 項目を実装する。

- A. 実行層の制約: `permissions.deny` が無く `.env` が可読、廃止済み hook が 4 本残り毎 tool call でシェルを起動している
- B. レビューゲートの証拠返却: 4 agent に `effort` が無く、security-reviewer に編集権限があり、finding の判定語彙が agent ごとに違う
- C. セッションをまたぐ引き継ぎ: codex-flow の途中状態（どのユニットが APPROVE / 再委譲中 / merge 済みか）が会話と scratchpad にしか無い

あわせて同レポートで見つけた不整合 2 点（pr-helper の push に承認ステップが無い、codex-impl の commit が codex-flow と違い確認なし）を直す。

変更対象はすべてプロンプト・設定ファイル（JSON / Markdown / shell）で、アプリケーションコードは無い。採用価値「中」「低」は対象外（末尾「後続候補」）。

## 全体設計

| 柱 | 変更 | ユニット |
|---|---|---|
| A 実行層 | settings の deny 8 件と hook 削除 / opt-in hook の出力形式を現行 docs の形式へ / 外部書込の再試行方針 / rules への 1 行 | U1, U6, U3, U4, U5 |
| B レビューゲート | 4 agent に `effort: high` / security-reviewer から Write, Edit を除去 / finding に Verdict, Evidence, Missing evidence の 3 欄 / 修正後の再レビュー手順 | U2, U3, U5 |
| C 引き継ぎ | progress ファイルの規約を codex-delegate に定義し、codex-impl / codex-flow が読んで再開する / README に運用メモ | U4, U3, U7 |

実行者と制約:

- 各ユニットは 30 行以内の編集なので **Claude 直接実装を推奨**（codex-flow の「Claude 直接相当なら直接」規定）。Codex に委譲できる粒度でも書いてある。委譲するなら RED / GREEN が機械的な U2 と U6 が向く
- Claude の Bash sandbox は `rules/` と `claude-global/CLAUDE.md` への書込を拒否する。U5 は Edit ツールで行う（sandbox 外で動く codex exec でも可）
- **ユーザー作業**（Claude / Codex では書けない）: live の `~/.claude/settings.json` へ U1 と同じ deny 追加と hook 削除を反映する。U1 完了後ならいつでもよい
- 検証は全ユニット共通で `npm test`（= `claude plugin validate .` + 構造チェック + eslint + markdownlint）が 0 終了。ユニット固有の受け入れ条件は grep / jq / node で機械判定する
- commit はユニットごとに Claude が行う。設計書は委譲前にベースブランチへ commit する

## 契約（ユニット間の境界面）

1. **verdict 語彙**: finding ごとの `Verdict:` は `verified` / `incorrect` / `unresolved` の 3 値。`verified` = 証拠で確認した欠陥、`incorrect` = 対象の主張（コード・テスト・PR 説明・設計書の記述）が証拠で否定された欠陥で、所見の撤回ではない、`unresolved` = 未確認で `Missing evidence:` が必須。commit を止めるのは CRITICAL / HIGH の `verified` と `incorrect`。codex-auditor の受け入れ条件判定は既存の `PASS` / `FAIL` / `UNVERIFIABLE` を維持し、`UNVERIFIABLE` には `Missing evidence:` を必須にする（`unresolved` 相当）
2. **finding の 3 欄**（U2 の 4 agent と U3 の code-review 手順が同じ文言を使う）:

   ```text
   Verdict: verified | incorrect | unresolved
   Evidence: <file:line> + <確認に使ったコマンドと出力の要点、または advisory の URL>
   Missing evidence: <unresolved のときのみ。どのテスト・コマンド・設定が見えれば決まるか>
   ```

3. **progress ファイル**: 設計書と同じディレクトリに `<設計書ファイル名から .md を除いたもの>.progress.md`（例 `docs/feature-x.md` → `docs/feature-x.progress.md`）。見出しは固定 6 つ `## Task` `## Outputs` `## Completed` `## Decisions` `## Open issues` `## Next action`、任意で `## Review time / Fixes`。U3（codex-impl / codex-flow）、U4（codex-delegate）、U7（README）がこの名前と見出しを使う。scratchpad には置かない（セッション終了で消える）
4. **effort**: 4 agent とも `effort: high`（agent frontmatter の正式フィールド。値は low / medium / high / xhigh / max）。`scripts/ci/validate-agents.js` の必須項目に `effort` を加える
5. **deny ルール**: 次の 8 件で固定。範囲は `.gitignore` の secrets 対象と同じで、`.env` 系は任意の深さに当てるため `**/` を付ける（`./.env` は作業ディレクトリ直下にしか当たらない）。`.env.example` と、`.gitignore` と同じく `.env.production` などは対象外。[permissions docs](https://code.claude.com/docs/en/permissions) によると Read の deny は同じパスの Read / Edit / Write ツールと、Bash の `cat` `head` `tail` `sed` と入力リダイレクトに効く。`grep -r` のようにファイル名を書かないコマンドや、node / python スクリプトが自前で開くファイルには効かないので、そこは Bash sandbox が担う。雛形は sandbox を有効にしない（利用者が `/sandbox` で有効にする）。作業ディレクトリの外（worktree 並列の `../<proj>-uN/.env`）は `**/` でも当たらない

   ```json
   "deny": [
     "Read(**/.env)",
     "Read(**/.env.local)",
     "Read(**/.env.*.local)",
     "Read(**/*.pem)",
     "Read(**/*.key)",
     "Read(**/secrets.json)",
     "Read(~/.ssh/**)",
     "Read(~/.codex/auth.json)"
   ]
   ```

   codex-delegate の前提チェック（`~/.codex/auth.json` の有無）は `test -f` で行い、内容を読まない

## 実装ユニット

### U1: settings.json の deny 追加と hook 削除

- **成果物**: `claude-global/settings.json` に `permissions.deny`（契約 5 の 8 件）が入り、`hooks` キーが消えた状態
- **対象ファイル**: `claude-global/settings.json` のみ
- **触らない**: `permissions.allow` の 72 件、`defaultMode`、`model` 以下の他キー、live の `~/.claude/settings.json`（ユーザー作業）、`.devcontainer/postCreate.sh`
- **テスト**: 下記 jq と `npm test`
- **受け入れ条件**:
  - `jq -e '.permissions.deny | length == 8' claude-global/settings.json` が成功
  - `jq -e '.permissions.deny | index("Read(**/.env)") != null and index("Read(~/.codex/auth.json)") != null' claude-global/settings.json` が成功
  - `jq -e 'has("hooks") | not' claude-global/settings.json` が成功
  - `jq -e '.permissions.allow | length == 72' claude-global/settings.json` が成功（allow 不変）
  - `npm test` が 0 終了
- **依存**: なし

### U2: レビュワー agent の effort・権限・出力形式

- **成果物**: 4 agent に `effort: high`、security-reviewer から `Write` `Edit` を除去、4 agent の出力形式に契約 2 の 3 欄、`validate-agents.js` が `effort` を必須化した状態
- **対象ファイル**: `agents/code-reviewer.md`、`agents/codex-auditor.md`、`agents/spec-reviewer.md`、`agents/security-reviewer.md`、`scripts/ci/validate-agents.js`
- **変更箇所**:
  - 4 agent の frontmatter に `effort: high` を 1 行追加（`model: inherit` は残す）
  - `agents/security-reviewer.md` 4 行目の tools を `["Read", "Grep", "Glob", "Bash", "Skill"]` に。3 行目の description の「detection and remediation specialist」を「detection specialist」に。本文に「修正は本体エージェントが security-review skill を使って行う。このエージェントは所見と修正案を返す」を 1 行。「Emergency Response」の「verify the fix works」は「修正案を示す」に改める
  - `agents/code-reviewer.md` の「Review Output Format」ブロックの `Fix:` の後に契約 2 の 3 行を追加
  - `agents/codex-auditor.md` の受け入れ条件判定（PASS / FAIL / UNVERIFIABLE）に「UNVERIFIABLE には `Missing evidence:` で欠けている証拠（実行できなかったコマンド、無いテスト、見えない設定）を必ず書く」を追加し、FINDINGS 行の形式に `Evidence:` を加える
  - `agents/spec-reviewer.md` の FINDINGS 形式に `Verdict:` と `Evidence:`（Read / Grep で確認した file:line）を加える
  - `agents/security-reviewer.md` の「Critical Issues」形式に契約 2 の 3 欄を加える
  - `scripts/ci/validate-agents.js` の `REQUIRED_FIELDS` を `['model', 'tools', 'effort']` に
- **テスト**: `node scripts/ci/validate-agents.js`、`npm test`
- **手順（TDD 順）**: (1) `REQUIRED_FIELDS` に `'effort'` を足し、`node scripts/ci/validate-agents.js` が 4 件の `Missing required field: effort` で exit 1 になることを確認（RED） (2) 4 agent に `effort: high` を入れて exit 0（GREEN） (3) tools と出力形式を修正
- **受け入れ条件**:
  - `grep -L '^effort: high$' agents/*.md` の出力が空
  - `sed -n 4p agents/security-reviewer.md | grep -c -E 'Write|Edit'` が 0
  - `grep -l 'Missing evidence' agents/*.md | wc -l` が 4
  - `grep -c "'effort'" scripts/ci/validate-agents.js` が 1 以上
  - `node scripts/ci/validate-agents.js` と `npm test` が 0 終了
  - 4 agent のチェックリスト本文と `model: inherit` は未変更（`git diff --stat` の増減が各 agent 20 行以内）
- **依存**: なし

### U3: command の再開ルール・承認・再レビュー・再試行

- **成果物**: code-review に修正後再レビュー、codex-impl に progress 再開ルールと commit 前確認、codex-flow に progress の作成と報告生成、vuln-fix に PR 作成の再試行方針が入った状態
- **対象ファイル**: `commands/code-review.md`、`commands/codex-impl.md`、`commands/codex-flow.md`、`commands/vuln-fix.md`
- **変更箇所**:
  - `commands/code-review.md`: 手順 6「CRITICAL / HIGH を修正したら、修正したファイルだけを対象に code-reviewer を再実行し、呼び出し元とテストの崩れを確認する」、手順 4 の報告に「finding は Verdict / Evidence / Missing evidence 付き」を追記
  - `commands/codex-impl.md`: 手順 1 の前に「`$ARGUMENTS` が `*.progress.md`、または設計書の隣に `<設計書名>.progress.md` があれば読み、Next action から続ける。Completed のユニットは再委譲しない」。末尾の注意「commit は監査完了後に Claude が行う」を「commit は監査完了後、ユーザーの確認を得てから Claude が行う」に
  - `commands/codex-flow.md`: 手順 3 の設計書ゲート通過時に progress ファイルを作成（契約 3 のパス）、手順 5 の監査ループで verdict ごとに更新、手順 6 の報告は progress ファイルの Completed / Decisions / Open issues から生成、と追記
  - `commands/vuln-fix.md`: 「## 6. PR を作る」に「push / `gh pr create` がタイムアウト・失敗したら `git remote -v` と `gh pr list --head <branch>` で宛先と既存 PR を確認してから再試行する（二重 PR と別 remote への push を防ぐ）」
- **触らない**: `commands/codex-spec.md`、`commands/plan.md`、`commands/security-audit.md`、各 command の description 行
- **テスト**: `node scripts/ci/validate-commands.js`、`npm test`
- **受け入れ条件**:
  - `grep -c 'progress.md' commands/codex-impl.md` が 1 以上、`grep -c 'progress' commands/codex-flow.md` が 2 以上
  - `grep -c 'ユーザーの確認' commands/codex-impl.md` が 1 以上
  - `grep -c 'gh pr list --head' commands/vuln-fix.md` が 1
  - `grep -c 're-run' commands/code-review.md` が 1 以上、`grep -c 'Missing evidence' commands/code-review.md` が 1 以上
  - `node scripts/ci/validate-commands.js` と `npm test` が 0 終了
- **依存**: なし（契約 2・3 の文言に従う）

### U4: skill の progress ファイル規約と push 承認

- **成果物**: codex-delegate に progress ファイルの節、pr-helper に push 前の確認と再試行方針が入った状態
- **対象ファイル**: `skills/codex-delegate/SKILL.md`、`skills/pr-helper/SKILL.md`
- **変更箇所**:
  - `skills/codex-delegate/SKILL.md`: 「## 監査ループ」の直前に「## 進捗ファイル（セッションをまたぐ引き継ぎ）」を追加。内容は (a) 契約 3 のパス規約と「scratchpad に置かない」理由 (b) 6 見出しの雛形をコードブロックで (c) 更新タイミング 5 点: 設計書ゲート通過後 / 各ユニットの委譲開始時（log と `-last.md` のパスを Outputs へ）/ 各監査 verdict 後 / 各 merge 後 / commit 前 (d) 最終 commit 時に削除するか設計書の変更履歴へ畳み、残骸を commit しない (e) 任意の `## Review time / Fixes` 欄（レビューに掛けた時間と修正量。設定変更の前後比較に使う）。「## 報告」に「報告は progress ファイルの Completed / Decisions / Open issues から作る」を 1 行
  - `skills/pr-helper/SKILL.md`: 「### 3. Push to Remote」の push コマンドの前に「push 先 branch と `git log origin/main..HEAD --oneline` の要約を示し、ユーザーの確認を得てから push する」。同節の末尾に「タイムアウト・失敗時は `git remote -v` と `gh pr list --head <branch>` で宛先と既存 PR を確認してから再試行する」
- **触らない**: codex-delegate の「委譲の基本形」「並列実装」「監査ループ」の既存手順、pr-helper の PR body テンプレート、`skills/commit-helper/SKILL.md`
- **テスト**: `node scripts/ci/validate-skills.js`、`npm test`
- **受け入れ条件**:
  - `grep -c '^## 進捗ファイル' skills/codex-delegate/SKILL.md` が 1
  - `grep -c -E '^## (Task|Outputs|Completed|Decisions|Open issues|Next action)$' skills/codex-delegate/SKILL.md` が 6（雛形のコードブロック内）
  - `grep -c '\.progress\.md' skills/codex-delegate/SKILL.md` が 1 以上
  - `awk '/^### 3\. Push to Remote/,/^### 4\./' skills/pr-helper/SKILL.md | grep -c 'confirmation'` が 1 以上、同範囲で `grep -c 'gh pr list --head'` が 1
  - `node scripts/ci/validate-skills.js` と `npm test` が 0 終了
- **依存**: なし

### U5: rules の追記

- **成果物**: hooks.md に deny の適用範囲、git-workflow.md に修正後再レビューが入った状態
- **対象ファイル**: `rules/hooks.md`、`rules/git-workflow.md`
- **変更箇所**:
  - `rules/hooks.md`: 「Prefer the built-in Bash sandbox ...」の段落の後に「`Read` / `Edit` deny rules cover the file tools, `cat` / `head` / `tail` / `sed` / `tee` and redirections in Bash. They do not cover node / python scripts that open files themselves; the Bash sandbox is the enforcement for that」を追加
  - `rules/git-workflow.md`: 「Feature Implementation Flow」を「Plan Mode (phases) → tests first (`dcc:tdd-workflow` skill) → **dcc:code-reviewer** (fix CRITICAL/HIGH, then re-review the fixed files) → commit with conventional format」に
- **触らない**: 他の rules ファイル、両ファイルの他の節
- **テスト**: `node scripts/ci/validate-rules.js`、`npm test`
- **受け入れ条件**:
  - `grep -c 're-review' rules/git-workflow.md` が 1
  - `grep -c 'sandbox' rules/hooks.md` が 2 以上
  - `node scripts/ci/validate-rules.js` と `npm test` が 0 終了
- **依存**: なし
- **注意**: Claude の Bash sandbox は `rules/` への書込を拒否する。Edit ツールで編集する

### U6: opt-in hook の出力形式更新とテスト

- **成果物**: `hooks/check-sensitive-paths.sh` の block 出力が PreToolUse の現行形式 `hookSpecificOutput.permissionDecision` になり、その振る舞いを固定するテストが `npm run validate` に組み込まれた状態
- **対象ファイル**: `hooks/check-sensitive-paths.sh`、`scripts/ci/test-check-sensitive-paths.sh`（新規）、`package.json` の `validate` スクリプト
- **変更箇所**:
  - block 出力 9 箇所を `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<理由>"}}` に統一する。理由に `$target` を含める箇所は JSON エスケープ（`jq -n --arg`）で壊れないようにする。判定ロジックと許可時の「出力なし・exit 0」は変えない
  - `scripts/ci/test-check-sensitive-paths.sh`: 下記 5 ケースを stdin に流し、期待どおりかを検査して失敗なら exit 1
  - `package.json` の `validate` の末尾に `&& bash scripts/ci/test-check-sensitive-paths.sh` を追加
- **触らない**: `README.md` の hook 登録例（登録方法は変わらない）、`rules/hooks.md`（U5）
- **テスト**: `bash scripts/ci/test-check-sensitive-paths.sh`、`bash -n hooks/check-sensitive-paths.sh`、`npm test`
- **手順（TDD 順）**: (1) テストスクリプトを先に書き、現状の hook に対して実行して deny の 4 ケースが失敗することを確認（RED） (2) hook を書き換えて全ケース成功（GREEN） (3) `package.json` に組み込む
- **受け入れ条件**（テストスクリプトの 7 ケース）:
  - `{"tool_name":"Read","tool_input":{"file_path":"../etc/passwd"}}` → `jq -er '.hookSpecificOutput.permissionDecision == "deny"'` が成功
  - `{"tool_name":"Bash","tool_input":{"command":"git push upstream main"}}` → 同上
  - `{"tool_name":"Read","tool_input":{"file_path":"/tmp/x\"y"}}` → 出力が `jq -e .` で妥当な JSON かつ deny
  - `{"tool_name":"Bash","tool_input":{"command":"ls"}}` → 出力が空で exit 0
  - `{"tool_name":"Bash","tool_input":{"command":"git log main..HEAD"}}` → 出力が空で exit 0（範囲演算子は親ディレクトリ扱いしない）
  - `{"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/id_rsa"}}` → deny
  - プロジェクト内の絶対パス（`$CLAUDE_PROJECT_DIR/README.md`）の Read → 出力が空で exit 0
  - `grep -c '"decision"' hooks/check-sensitive-paths.sh` が 0
  - `bash -n hooks/check-sensitive-paths.sh` と `npm test` が 0 終了
- **依存**: なし

### U7: README の運用メモ

- **成果物**: README に deny と hook 削除の説明、progress ファイルの規約、設定変更の比較方法、2026-11 の履歴が入った状態
- **対象ファイル**: `README.md`
- **変更箇所**:
  - 「## hook」の冒頭に「`claude-global/settings.json` は `permissions.deny` で `.env` / 鍵ファイルの読み取りを塞ぐ（8 件）。live の `~/.claude/settings.json` へは `dcc link-host` が初回コピーするだけなので、既存環境では手で同じ deny を足し、廃止済みの continuous-learning hook を消す」を 2〜3 行
  - 「## Claude ⇔ Codex ハイブリッド運用」に「長いタスクの状態は設計書の隣の `<設計書名>.progress.md`（Task / Outputs / Completed / Decisions / Open issues / Next action）に置く。新セッションでは `/dcc:codex-impl <progress ファイル>` で Next action から再開する」を 1〜2 行
  - 「## メンテナンス」に「設定（effort / deny / hook）の変更は 1 つずつ、同じタスク・同じ受け入れ条件で progress ファイルの Review time / Fixes を前後比較してから残す」を 1 行
  - 「## カスタマイズ履歴」に「### 2026-11 長時間タスク向けハーネス強化」を追加し、A / B / C の要点を 3 行
- **触らない**: セットアップ手順、command / agent / skill の一覧表、ディレクトリ構成表
- **テスト**: `npm run lint`
- **受け入れ条件**:
  - `grep -c '\.progress\.md' README.md` が 1 以上
  - `grep -c 'permissions.deny' README.md` が 1 以上
  - `grep -c '^### 2026-11' README.md` が 1
  - `npm test` が 0 終了
- **依存**: なし（文言は契約 3・5 に従う）

## 並列マップ

- U1〜U7 は対象ファイルが重複しないので全ユニット並列可
- 推奨順（Claude 直接・1 セッション・ユニットごとに commit）: U1 → U2 → U6（機械テストがあるもの）→ U3 → U4 → U5 → U7
- Codex に委譲する場合: Wave 1 = U2, U6（worktree 並列）、Wave 2 = U3, U4, U7。U1 は 1 ファイルの JSON 編集なので Claude 直接、U5 は sandbox の書込制限があるので Claude の Edit ツール
- ユーザー作業（U1 の後、任意のタイミング）: `~/.claude/settings.json` に契約 5 の deny 8 件を追加し `hooks` を削除

## 統合後の確認（手動・1 回）

1. `claude doctor` で deny ルールの警告（matches no tool 等）が無い
2. `/permissions` に deny 8 件が表示され、`.env` と `sub/.env` の Read と `cat .env` が拒否され、`.env.example` は読める
3. codex-delegate の worktree 準備（`cp .env "$w/"`）が deny で止まるかを確かめ、止まるなら skill に「.env は利用者がコピーする」と書く
4. `/agents` で 4 agent の effort が high
5. 新セッションでダミーの `docs/dummy.progress.md`（Next action に「U2 の監査を実行」）を作り、`/dcc:codex-impl docs/dummy.progress.md` を実行して Next action から続行する旨の応答が出る。確認後にダミーは削除
6. 結果を README の「## メンテナンス」に 1 行で記録する

## 第 2 段: 後続候補の実装（2026-11-06）

「後続候補」のうち、利用者の判断が要らない 4 件を同じ branch で実装する。`rules/` の整理（項目 1）は symlink で全プロジェクトに即反映され、どこまで削るかは利用者が決めるので対象外のまま残す。

### U8: hook の抜け道を塞ぐ

- **成果物**: `hooks/check-sensitive-paths.sh` が Bash コマンドを単純コマンドと語に分けて判定し、下記の抜け道が塞がった状態
- **対象ファイル**: `hooks/check-sensitive-paths.sh`、`hooks/check-sensitive-paths-bash.sh`（Bash の判定。800 行の上限に収めるため分けた）、`scripts/ci/test-check-sensitive-paths.sh`、`README.md` の hook 節、`rules/hooks.md`（matcher）
- **変更箇所**:
  - Bash: bash 3.2 の規則（引用符・`\`・`$'...'`・行継続・`;` `|` `&`・リダイレクト・ヒアドキュメント・ヒアストリング・`$(...)` / バッククォート・`sh -c`・`eval`）で単純コマンドと語に分ける 1 文字ずつのトークナイザにする。外部コマンド（`tr` 等）を使わず bash 3.2 の機能だけで行う（コマンドが無いと判定が空になり素通しになるため）。ヒアドキュメント・ヒアストリングはシェルに渡すときはコマンドとして、それ以外は引用しない区切りの本文の `$(...)` / バッククォートだけを見る。64 KB を超えるコマンドは拒否
  - `..`: 語が `..`、`../` 始まり、`/../` を含む、`/..` 終わりのどれかなら拒否する。`git` を含むコマンドでも省略しない（`main..HEAD` のような範囲演算子は該当しない）
  - git: 語 `git`（または `*/git`）ごとに、グローバルオプションを許可リストで読み飛ばしてサブコマンドを取る。サブコマンドも許可リストで、無いものは利用者の alias なら展開して見て、それ以外は拒否。`push` はオプションを許可リストで見て（省略形・束ね書きは拒否）、最初の位置引数（remote）と `--repo` が `origin` 以外なら拒否。`remote add` / `set-url` / `rename`、許可リストに無いキーへの `-c` / `--config-env` / `git config` の書き込み、節の rename / remove を拒否。`clone` / `ls-remote` / `submodule` は URL を含めば、`fetch` / `pull` / `archive` は最初の引数が URL なら（`://` と `user@host:` はどの位置でも）拒否。`rebase -x`・`difftool -x`・`submodule foreach`・`bisect run` の文字列はコマンドとして見る
  - ホーム・環境変数: 引用符の外か `"..."` の中の `$HOME` / `${HOME}`、`~` で始まる語、ディレクトリを付けない `cd`（`cd -P`・`builtin cd`・`command -p cd`・リダイレクトだけ付いたものを含む）、`HOME=` / `XDG_CONFIG_HOME=`、許可リストに無い `GIT_*=` を拒否。`GIT_PAGER` / `GIT_EDITOR` / `GIT_SEQUENCE_EDITOR` の値はコマンドとして見る
  - 絶対パス: 全ての語（リダイレクト先、`=` `@` `,` で区切った各片、`file://` の後ろ、短いオプションにくっついた値、ブレース展開の各候補も）について、作業ディレクトリ・Claude の一時ディレクトリ・無害な `/dev` 以外で、先頭の要素が実在するもの（`/etc/...` など）を拒否。`/api/` のような正規表現の語は先頭要素が無いので通す。実在するパスは symlink をたどった先が外なら拒否
  - 保護するファイル: `.git`・`.git/config`・`.git/hooks`・`.claude/hooks`・`.claude/settings*.json` について、Bash からの参照と Edit / Write / NotebookEdit での書き込みを拒否（大文字小文字・`//`・`/./` の違いは同一視）
  - 一時ディレクトリ: `/tmp/claude` の前方一致をやめ、`(/private)?/tmp/claude(-<数字>)?` の直下だけを許可する
  - Read 系: `file_path` に加えて `path`（Grep / Glob）、`notebook_path`（NotebookEdit）、Glob の `pattern` を見る。登録例の matcher を `Bash|Read|Edit|Write|Grep|Glob|NotebookEdit` にする
- **触らない**: fail closed の部分（jq・入力検証・cat）と出力形式。fail closed は、作業ディレクトリが `/` のとき、入力の `cwd` がディレクトリでないとき、パスの欄が文字列でないとき、Bash の判定ファイルが無いとき、判定がクラッシュしたとき（サブシェルで動かし、0 / 2 以外の終了は exit 2）にも広げる。1 語のブレースは 16 個、コマンドは 32 KB まで
- **テスト**: `bash scripts/ci/test-check-sensitive-paths.sh`、`npm test`
- **手順（TDD 順）**: テストを先に足して現状の hook で新しい拒否ケースが失敗することを確認（RED）→ hook を直して全件成功（GREEN）
- **受け入れ条件**（テストスクリプトに追加するケース）:
  - 拒否: `cat ../secret; git status`、`git -C .. status`、`cd ..`、`git push evil origin`、`git push evil main # origin`、`git push --repo=https://example.com/x.git`、`git -c remote.origin.url=https://example.com/x.git push origin main`、`git push https://example.com/x.git main`、`sh -c "git push evil main"`、`echo ok && git push upstream main`、`git remote set-url origin https://example.com/x.git`、`git config remote.origin.url https://example.com/x.git`、`git clone --depth 1 git@example.com:x.git`、`cat $HOME/.ssh/id_rsa`、`cat "${HOME}/.aws/credentials"`、`cat ~root/.profile`、`cd && cat .ssh/id_rsa`、`cat /etc/passwd`、`ls 2>/etc/x`、`cat /tmp/claude-evil/x`、Read の `/tmp/claude-evil/x`、Grep の `path: /etc`、Glob の `path: ..`、Glob の `pattern: /etc/*`、NotebookEdit の `notebook_path: /etc/x.ipynb`
  - 素通し: `git diff HEAD~1..`、`git log ..origin/main`、`git push`、`git push -u origin feat/x`、`git push -o ci.skip origin main`、`git config --get remote.origin.url`、`grep -E '/api/' src`、`ls 2>/dev/null`、作業ディレクトリ内の絶対パスを含む `cat`、`/tmp/claude/x` と `/private/tmp/claude-501/x` の Read、`path` 無しの Grep
  - 既存の 20 ケースが引き続き成功し、`npm test` が 0 終了
- **依存**: なし

### U9: 長時間タスクの始め方（`/goal` と事前確認）

- **成果物**: `commands/codex-flow.md` に「長時間走らせるとき」節があり、利用者が打つ事前確認（`/context` `/agents` `/permissions`）と `/goal` の条件テンプレが書かれた状態
- **対象ファイル**: `commands/codex-flow.md`
- **要点**: `/goal` の評価役は会話に出た内容しか見ないので、progress ファイルとテスト結果を出力させる条件にする。設計書ゲートより前に設定すると確認待ちでも評価が回るので、ゲートで「続行」の代わりに設定する。commit・merge しないことを条件に入れ、ターン上限を付ける
- **受け入れ条件**: `grep -c '/goal' commands/codex-flow.md` が 1 以上、`grep -q '/permissions' commands/codex-flow.md` が成功、`npm test` が 0 終了
- **依存**: なし

### U10: statusline のコストを Claude Code の集計値にする

- **成果物**: `claude-global/statusline.sh` がコストを `cost.total_cost_usd`（セッション累計の推定額）から表示し、`effort.level` があればモデル名の横に出す状態
- **対象ファイル**: `claude-global/statusline.sh`、`scripts/ci/test-statusline.sh`（新規）、`package.json` の `validate`
- **背景**: 現状は `context_window.total_input_tokens`（いま context にある token 数）に Sonnet の単価を掛けており、累計の費用でもモデル別の単価でもない
- **受け入れ条件**: `cost.total_cost_usd: 1.234` の入力で出力に `$1.23`、`cost` 無しで `$0.00`、`effort.level: "high"` で `high` を含み、`current_usage: null` でも exit 0。`npm test` が 0 終了
- **依存**: なし

### U11: 監査 skill の MCP 接続先確認

- **成果物**: `skills/supabase-vercel-audit/SKILL.md` の Layer A「実行手段」に、Supabase MCP を使う前に `get_project_url` で接続先が監査対象かを確かめる 1 行がある状態
- **対象ファイル**: `skills/supabase-vercel-audit/SKILL.md`
- **受け入れ条件**: `grep 'Supabase MCP:' skills/supabase-vercel-audit/SKILL.md | grep -q 'get_project_url'` が成功、`npm test` が 0 終了
- **依存**: なし

## 後続候補（この設計書の対象外）

- 項目 1（中）: `rules/` の整理（`rules/hooks.md` のキット説明、`rules/agents.md` のカタログ、`rules/patterns.md` の Skeleton Projects）と TDD 手順の 3 重化解消。symlink で全プロジェクトに即反映されるので、残す範囲を利用者が決めてから
- 項目 6（中）の残り: 本体 effort を下げるかの判断。statusline に effort とコスト（U10）が出るので、数セッション分を見てから決める
- hook で塞げないもの（2026-11-09 の 2 回目のレビュー後、利用者の判断でレビューの往復を打ち切った。強制力は deny と sandbox が担う）: 実行時にしか決まらない値（変数・コマンドの出力・glob・`xargs` の入力。`bash -c "$(cat <<'EOF' ... EOF)"` も含む）、スクリプト経由の操作、実際のシェル（多くは zsh）が bash 3.2 と違って読む構文（zsh 固有の展開・`${~HOME}`・glob 修飾子、`$(...)` の中の `case` のパターン、計算式の中の `<<`、改行をまたいでシェルに渡すヒアドキュメント、`{ cd; }` のような複合コマンドの中の cd）、別の場所に書いた git ディレクトリの origin への push（`git -C <dir> push origin`、`--git-dir`）、`read` / `export` で組み立てる環境変数、`env -S` / `bash -c -x` の文字列、パラメータ展開の既定値（`${u:-/etc/passwd}`）、`ln -s .git g` のような別名経由の `.git` 書き込みと `.git/config.worktree`、`:` で区切った `..`（`docker -v ..:/h`）、git の proxy 設定、curl などによる一般的な外部送信。macOS ではパスの大文字小文字を区別しないため `/users` のような語も拒否される。`.git/hooks` を含む語（`grep -rn ".git/hooks" docs`）や `PATH=/opt/homebrew/bin:$PATH` も拒否される（安全側の誤検知）
- idc-app と tamagohub-app の hook コピーの更新（利用者作業）

## 変更履歴

- 2026-11-04: 初版。差分レポートの「高」3 項目（実行層・レビューゲート・引き継ぎ）と不整合 2 点（pr-helper の push 承認、codex-impl の commit 確認）
- 2026-11-04: code-reviewer（Block、HIGH 2 件）と security-reviewer（APPROVE WITH CHANGES）の指摘を反映。hook を jq 不在・壊れた入力で fail closed に、.env の deny を `**/` で任意の深さに、`incorrect` の CRITICAL / HIGH も commit を止める、commit 確認の範囲を作業ブランチへの merge・commit に限定、codex-impl 単独でも progress を作る、progress を `.git/info/exclude` に入れる、など
- 2026-11-04: 2 回目のレビュー（code-reviewer: Warning、security-reviewer: APPROVE WITH CHANGES。1 回目の指摘はすべて解消）の指摘を反映。spec-reviewer の verdict 定義を契約に揃え、hook は空・null・`{}`・複数値の入力と cat の失敗でも exit 2 に、README の hook 登録例を `${CLAUDE_PROJECT_DIR}` と `"onFailure": "block"` に、deny の範囲を「作業ディレクトリ配下」と明記
- 2026-11-06: 第 2 段（U8〜U11）を追加。後続候補のうち hook の抜け道、`/goal` テンプレと事前確認（項目 6・7）、statusline のコスト（項目 9）、MCP の接続先確認（項目 3）を実装し、後続候補を残りだけにした
- 2026-11-09: 第 2 段の 1 回目のレビュー（code-reviewer: Block、HIGH 2 件。security-reviewer: APPROVE WITH CHANGES、HIGH 7 件）を反映。hook を bash と同じ規則で語に分けるトークナイザと git オプションの許可リストで作り直し、branch / alias / include の設定、`.git/config` の書き換え、途中の symlink、`/dev/tcp` なども塞いだ。statusline のコストはロケールに依らない整数計算に、codex-flow の `/goal` 節に permission mode の注意を追加
- 2026-11-09: 第 2 段の 2 回目のレビュー（code-reviewer: Block、HIGH 6 件。security-reviewer: BLOCK、HIGH 7 件）。`>&-`、`bash -c --`、入れ子のバッククォート、引用しない区切りのヒアドキュメント、ヒアストリングと `source`、`HOME` / `XDG_CONFIG_HOME` と `GIT_*` の差し替え、`.GIT/config` などの表記ゆれ、symlink のディレクトリ越しの新規ファイル、`rebase -x` / `submodule foreach` / `core.pager` に隠したコマンド、`send-pack` などのサブコマンドを塞ぎ、git のサブコマンド・設定キー・環境変数も許可リストにした。判定のクラッシュで素通しになる問題は、判定をサブシェルで動かして exit 2 にし、ブレース数とコマンド長に上限を付けた。直すたびにシェルの解釈のずれから新しい抜け道が出るため、利用者の判断でここでレビューの往復を打ち切り、残りは「後続候補」の「hook で塞げないもの」に記録した
