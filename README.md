# dark-claude-code

Claude Code 用の個人テンプレート。
[`affaan-m/everything-claude-code`](https://github.com/affaan-m/everything-claude-code) の fork から派生し、TypeScript / Ruby / PHP 中心の業務向けに curate したもの。

## 方針

- **upstream 非追従** — `everything-claude-code` の更新は自動追跡しない。必要な変更は差分を見て手動取込。
- **使用言語に最適化** — TS / Ruby / PHP に絞り、Go / Java / Spring / Django / Python 関連は削除済み。
- **cp で展開** — plugin としてではなく、各プロジェクトの `.claude/` に `cp` / `rsync` で配る。
- **痛点駆動** — 実使用で困ったら追加・削除。早すぎる最適化はしない。

## デプロイ方法

基本は後述の `dcc init` / `dcc sync` を使う。以下は wrapper を使わない場合の手動手順。

### 新規プロジェクトに初回展開

```bash
cd <target-project>
mkdir -p .claude/scripts
cp -r ~/dark-claude-code/{commands,agents,skills,hooks,mcp-configs} .claude/
cp -r ~/dark-claude-code/scripts/hooks .claude/scripts/
```

### 既存プロジェクトに更新展開（既存ファイルを守る）

```bash
cd <target-project>
for d in commands agents skills hooks scripts/hooks; do
  mkdir -p .claude/$d
  rsync -av --update ~/dark-claude-code/$d/ .claude/$d/
done
```

`--update` でテンプレ側が新しいときだけ上書き。事前確認は `--dry-run` を付ける。

### dcc wrapper（推奨・CLI 完結）

`bin/dcc` が展開もコンテナ起動も 1 コマンドにまとめる。IDE 不要。

セットアップ（初回のみ）:

```bash
npm install -g @devcontainers/cli
ln -sf <このリポジトリ>/bin/dcc ~/.local/bin/dcc  # PATH 上の任意の場所
```

日常の使い方:

```bash
cd <target-project>
dcc init       # テンプレ (.claude/) + .devcontainer/ を展開（初回のみ）
dcc            # devcontainer 起動（未作成なら作成）+ claude 起動
```

サブコマンド一覧:

| コマンド | 動作 |
|---|---|
| `dcc` | devcontainer up + claude 起動（`dcc --continue` 等、引数は claude へ透過） |
| `dcc shell` | devcontainer up + bash で入る |
| `dcc up` | コンテナ起動のみ |
| `dcc rebuild` | コンテナ作り直し + claude 起動（devcontainer.json 変更後に） |
| `dcc init` | テンプレ + `.devcontainer/` + `AGENTS.md`/`CLAUDE.md`（symlink 共有）をカレントプロジェクトへ展開 |
| `dcc sync` | キットのテンプレ差分を `.claude/` へ反映（`rsync --update`） |
| `dcc link-host` | host の `~/.claude` / `~/.codex` をキット参照の symlink で構成（コンテナ無し運用） |
| `dcc kit` | **キット repo で claude を起動**。個別プロジェクトで気づいた改善をその場でキットに反映して PR を作る用 |

スクリプト本体はキット側にあるので、改善は symlink 経由で全プロジェクトに即反映される。`dcc` はカレントから上位へ `.devcontainer/` を探すため、プロジェクト内のどこからでも実行できる。

### devcontainer の中身

`postCreate.sh` がやること:

1. Claude Code CLI / Codex CLI を global install（`@anthropic-ai/claude-code`, `@openai/codex`）
2. `npm ci`（プロジェクト自身の `package-lock.json` があれば）
3. `rules/` が root にあれば `~/.claude/rules/` へ配置
4. `claude-global/` が root にあれば `~/.claude/` へ配置（グローバル `CLAUDE.md` / `settings.json` / `statusline.sh`。ホストのグローバル設定のミラー）
5. `codex-global/` が root にあれば `~/.codex/` へ配置（`config.toml` / `AGENTS.md`。認証情報は含めない）
6. root 直下にテンプレ (`commands/` 等) があれば `.claude/` へ展開（このキット開発時のドッグフーディング用。展開物は gitignore 済）。使う側プロジェクトでは `dcc init` の展開済み `.claude/` がそのまま使われる

`~/.claude`（`dcc-claude-home`）と `~/.codex`（`dcc-codex-home`）は named volume で、**この devcontainer を使う全プロジェクトが共有**する。つまりログイン・rules・グローバル設定はどこかで一度やれば済む — キット本体で一度 `dcc up` しておくのが手っ取り早い。

> `claude-global/settings.json` はホストと同じ許可リスト（`defaultMode: acceptEdits` 等）を含む。コンテナに配る前提の設定なので、緩すぎると感じたらここを削る。

認証（いずれも volume 永続化なので一度やれば全プロジェクト共有）:

- **Claude**: ホストに `ANTHROPIC_API_KEY` があれば `remoteEnv` で引き継ぐ（API 従量課金になる点に注意）。無ければコンテナ内で `claude` を起動してブラウザログイン
- **Codex**: ホストに `OPENAI_API_KEY` があれば `remoteEnv` で引き継ぐ。ChatGPT アカウントで使う場合は、host でログイン済みの `~/.codex/auth.json` を volume へコピーする:

  ```bash
  docker run --rm -v dcc-codex-home:/v -v ~/.codex:/host:ro alpine cp /host/auth.json /v/auth.json
  ```

  （コンテナ内での `codex login` は localhost コールバック前提のため通らないことがある）

VS Code / Cursor を使う場合は「Reopen in Container」でも同じ状態になる（`customizations.vscode` はその時だけ効く）。

> hook 定義（`hooks/hooks.json`）は `settings.json` へ自動マージはしない。参照スクリプトは `$CLAUDE_PROJECT_DIR/.claude/scripts/hooks/` を前提とする（`dcc sync` / 手動展開で配置される）。有効化は後述「hook の有効化」を手動で行う。
> イメージは Node 24 固定。Ruby / PHP プロジェクトでは `devcontainer.json` の `image` を差し替える。

### コンテナ無し（host 直）での利用

`dcc link-host` で host のグローバル設定をキット参照の symlink にする。キットを編集した瞬間に claude / codex の両方へ反映され、rsync での同期作業が不要になる。

| 対象 | 方式 |
|---|---|
| `~/.claude/CLAUDE.md` / `~/.claude/rules/` / `~/.claude/statusline.sh` / `~/.codex/AGENTS.md` | symlink（ツールが書き換えない読み取り専用のみ） |
| `~/.claude/settings.json` / `~/.codex/config.toml` | 無ければ初期値をコピー、あれば触らない（ツールが実行時に状態を書き込むため） |

既存の実体ファイルは `<name>.pre-dcc.<timestamp>` へ退避される。再実行は冪等。

プロジェクト側は `dcc init` が `AGENTS.md`（実体）+ `CLAUDE.md`（symlink）を用意するので、**指示ファイルは AGENTS.md を 1 つ書けば Claude Code / Codex の両方に効く**（Claude Code は AGENTS.md を直接読まないため symlink で共有する。公式ドキュメント推奨のパターン）。

## ディレクトリ構成

| パス | 役割 |
|---|---|
| `commands/` | スラッシュコマンド (28) |
| `agents/` | サブエージェント (15) |
| `skills/` | ワークフロー・ドメイン知識 (16) |
| `hooks/` | フックスクリプト (4) |
| `rules/` | 共通ルール (`~/.claude/rules/` へ配置) |
| `claude-global/` | グローバル設定 (`CLAUDE.md` / `settings.json` / `statusline.sh` → `~/.claude/` へ配置) |
| `codex-global/` | Codex CLI グローバル設定 (`config.toml` / `AGENTS.md` → `~/.codex/` へ配置)。`AGENTS.md` は `claude-global/CLAUDE.md` への symlink（単一ソース、コンテナ配布時に実体化） |
| `mcp-configs/` | MCP サーバ設定例 |
| `scripts/` | command 依存スクリプト (`/setup-pm` `/skill-create` 等) |
| `bin/` | host 側 wrapper (`dcc`) — 展開・コンテナ起動・キット改善の入口 |
| `schemas/` | hook / plugin の JSON スキーマ |
| `.devcontainer/` | devcontainer 定義 (`devcontainer.json` + `postCreate.sh`) |
| `everything-claude-code/` | 素材庫 (gitignore 済み、参照用 fresh clone) |

## 言語カバレッジ

| 言語 | patterns | testing | 備考 |
|---|---|---|---|
| TS / JS | `coding-standards`, `backend-patterns`, `frontend-patterns` | `tdd-workflow` (汎用) | Node / Express / Next.js / React |
| Ruby | `ruby-patterns` | `ruby-testing` | RSpec 中心、framework-agnostic |
| PHP | `php-patterns` | `php-testing` | PHPUnit 中心、framework-agnostic |

Rails / Laravel 等 framework 特化 skill は必要になったら追加。

## Claude ⇔ Codex ハイブリッド運用

役割分担: **Claude Code = 司令塔（設計・タスク分割・監査）、Codex = 実行部隊（実装・テスト・環境構築）**。

推奨パイプライン: `/codex-spec` → `/codex-impl` → 監査。一気通貫でよければ `/codex-flow`。

- `/codex-flow <タスク>` — 設計 → 委譲実装 → 監査を1コマンドで実行。レビューポイントは設計書ゲート（続行/修正/中止）と commit 前の2箇所。中規模までの明確なタスク向けで、設計を練り込みたい大物は 2 段階運用

- `/codex-spec <要件>` — Codex への委譲を前提とした設計書を作成。実装ユニットに分割し、各ユニットに成果物・受け入れ条件・境界・並列可否を明記する。作法は `skills/codex-spec` が定義。**委譲品質はこの設計書で決まる**
- `/codex-impl <設計書 or タスク>` — 設計書のユニットを `codex exec` に委譲し、Claude が `git diff` とテスト実行で監査するまでを一括で行う。作法は `skills/codex-delegate` が定義（委譲プロンプトの書き方・worktree 並列・監査ループ）
- 委譲の基本形は `codex exec -s workspace-write -C <dir> -o <最終メッセージファイル> "<タスク>" > <進捗ログ> 2>&1`。`--dangerously-bypass-approvals-and-sandbox` は使わない
- プロジェクト指示は `AGENTS.md`（`CLAUDE.md` は symlink）が Claude / Codex の両方に効く
- MCP 方式（従）: `claude mcp add -s user --transport stdio codex -- codex mcp-server`（`mcp-configs/` に定義あり）。単発のブロッキング呼び出しでコンテキストも消費するため、基本は skill 方式を推奨

## hook の有効化

`.sh` ファイルをコピーしただけでは動かない。プロジェクトの `.claude/settings.json` に登録が必要。

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-sensitive-paths.sh" }
        ]
      }
    ]
  }
}
```

含まれる hook：

| 名前 | 用途 |
|---|---|
| `check-sensitive-paths.sh` | 機密パスへのアクセス検知 |
| `format-ts.sh` | TypeScript 自動フォーマット (PostToolUse) |
| `prisma-generate.sh` | Prisma 使用時のコード生成 |
| `hooks.json` | hook 定義の共通サンプル |

## MCP 注意点

`mcp-configs/mcp-servers.json` は API トークンが必要な MCP（GitHub, Supabase, Vercel など）が含まれる。プロジェクトで使うときは：

1. 不要なものは `.claude/settings.json` の `disabledMcpServers` で無効化
2. 必要なトークンのみ環境変数で供給
3. 全 MCP 有効化はコンテキスト圧迫するので避ける

## メモリ管理コマンド

`~/.claude/projects/.../memory/` の永続メモリを扱う 3 コマンドを同梱（`~/.claude/commands/` と同内容）。

| コマンド | 用途 |
|---|---|
| `/save-memory` | 直近の会話から保存候補を抽出して提案 |
| `/memory-show` | 現在のメモリ内容を read-only で一覧 |
| `/memory-clean` | 古い / 重複 / 誤ったメモリを監査し剪定提案 |

新規プロジェクトで `commands/` を `cp` 配置すれば即利用可。

## カスタマイズ履歴 (2026-04)

- **Tier A 逆輸入** — 実プロジェクト (p-mill / repohub) から `commit-helper` `pr-helper` などの汎用スキルや spec-* agents を取り込み（後の精査で p-mill 特化分は除外）
- **Tier B 削除** — Python / eval-driven dev は使用見込みなしで削除
- **Tier C 削除** — Go / Java / Spring / Django / ClickHouse 関連を一括削除
- **Phase 5 追加** — Ruby / PHP の patterns / testing skill を新規作成
- **Cleanup 1** — upstream の assets 12MB / 翻訳 / ガイド類を削除（13MB → 1MB）
- **Cleanup 2** — spec-* agents を 7 → 3 に集約（RH 系の A/B/C 並列パターンに統一）
- **Cleanup 3** — p-mill 特化 commands (backlog / write-spec / propose-feature / migrate / add-api 等) を template から除去（元 copy は p-mill に残存）

## メンテナンス指針

- 不要だと感じた command/skill/agent は遠慮なく削除（git 履歴に残るので戻せる）
- 自作の追加は `commands/personal/` のようなサブディレクトリに切ると後で見分けやすい
- 大きな変更は branch で試してから main に merge
- upstream を見たいときは `everything-claude-code/` (gitignore 済) を更新

## ライセンス

MIT (upstream 由来)。`LICENSE` 参照。
