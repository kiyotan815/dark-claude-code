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

1. **verdict 語彙**: finding ごとの `Verdict:` は `verified` / `incorrect` / `unresolved` の 3 値。codex-auditor の受け入れ条件判定は既存の `PASS` / `FAIL` / `UNVERIFIABLE` を維持し、`UNVERIFIABLE` には `Missing evidence:` を必須にする（`unresolved` 相当）
2. **finding の 3 欄**（U2 の 4 agent と U3 の code-review 手順が同じ文言を使う）:

   ```text
   Verdict: verified | incorrect | unresolved
   Evidence: <file:line> + <確認に使ったコマンドと出力の要点、または advisory の URL>
   Missing evidence: <unresolved のときのみ。どのテスト・コマンド・設定が見えれば決まるか>
   ```

3. **progress ファイル**: 設計書と同じディレクトリに `<設計書ファイル名から .md を除いたもの>.progress.md`（例 `docs/feature-x.md` → `docs/feature-x.progress.md`）。見出しは固定 6 つ `## Task` `## Outputs` `## Completed` `## Decisions` `## Open issues` `## Next action`、任意で `## Review time / Fixes`。U3（codex-impl / codex-flow）、U4（codex-delegate）、U7（README）がこの名前と見出しを使う。scratchpad には置かない（セッション終了で消える）
4. **effort**: 4 agent とも `effort: high`（agent frontmatter の正式フィールド。値は low / medium / high / xhigh / max）。`scripts/ci/validate-agents.js` の必須項目に `effort` を加える
5. **deny ルール**: 次の 8 件で固定。`.gitignore` の secrets 対象と同じ範囲で、`.env.example` は残る。Read の deny は同パスの Edit / Write と、Bash の `cat` `head` `tail` `sed` `tee` とリダイレクトにも効く。node / python スクリプト経由のアクセスには効かないので、そこは Bash sandbox が担う

   ```json
   "deny": [
     "Read(./.env)",
     "Read(./.env.local)",
     "Read(./.env.*.local)",
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
  - `jq -e '.permissions.deny | index("Read(./.env)") != null and index("Read(~/.codex/auth.json)") != null' claude-global/settings.json` が成功
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
2. `/permissions` に deny 8 件が表示され、`.env` の Read が拒否される（`.env.example` は読める）
3. `/agents` で 4 agent の effort が high
4. 新セッションでダミーの `docs/dummy.progress.md`（Next action に「U2 の監査を実行」）を作り、`/dcc:codex-impl docs/dummy.progress.md` を実行して Next action から続行する旨の応答が出る。確認後にダミーは削除
5. 結果を README の「## メンテナンス」に 1 行で記録する

## 後続候補（この設計書の対象外）

- 項目 1（中）: `rules/` の整理（`rules/hooks.md` のキット説明、`rules/agents.md` のカタログ、`rules/patterns.md` の Skeleton Projects）と TDD 手順の 3 重化解消
- 項目 6（中）: `commands/codex-flow.md` の手順 0 に `/context` `/agents` `/permissions` の構成確認。本体 effort を下げるかは項目 9 の計測で判断
- 項目 7（中）: codex-flow 用の `/goal` 条件テンプレ（「全ユニットが codex-auditor で APPROVE、統合ブランチでテストが 0 終了、progress の Open issues が明示。or stop after 12 turns」）
- 項目 9（中）: `claude-global/statusline.sh` のコスト単価の更新
- 項目 3（低）: supabase-vercel-audit の Layer A 冒頭に MCP 疎通確認 1 行

## 変更履歴

- 2026-11-04: 初版。差分レポートの「高」3 項目（実行層・レビューゲート・引き継ぎ）と不整合 2 点（pr-helper の push 承認、codex-impl の commit 確認）
