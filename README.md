# dark-claude-code

Claude Code 用の個人キット。Claude ⇔ Codex のハイブリッド開発ワークフローと、レビューゲート・チーム規約 skill を **plugin（`dcc@dark-claude-code`）** として配る。
[`affaan-m/everything-claude-code`](https://github.com/affaan-m/everything-claude-code) の fork から派生し、2026-10 に使用ログをもとに棚卸しして plugin 化した。

## 方針

- **使われているものだけ残す** — 1 年分の入力履歴とセッション記録で使用回数を数え、使われていない command / agent は消す。迷ったら消して git 履歴で戻す
- **plugin で配る** — 各プロジェクトの `.claude/` へコピーする方式は廃止。host は `dcc link-host`、コンテナは `postCreate.sh` が install する
- **モデルに任せる** — 計画・探索・ビルド修正は組み込み agent（`Plan` / `Explore`）と Fable 級モデルで足りるので専用 agent は持たない。残す agent はレビューゲート（code / security / spec / Codex 監査）だけ
- **upstream 非追従** — `everything-claude-code` の更新は手動で差分取込

## セットアップ

### host（コンテナ無し）

```bash
ln -sf <このリポジトリ>/bin/dcc ~/.local/bin/dcc   # PATH 上の任意の場所
dcc link-host
```

`link-host` は `~/.claude/CLAUDE.md` / `~/.claude/rules/` / `~/.claude/statusline.sh` / `~/.codex/AGENTS.md` をキットへの symlink にし、`settings.json` / `config.toml` は無ければ初期値をコピーする。続けてキットのローカルパスを marketplace として登録し `dcc@dark-claude-code` を install する。**ローカルパス由来の plugin は in-place で読み込まれる**ので、キットを編集すれば次のセッション（または `/reload-plugins`）で反映される。

plugin は user scope に入るので、**各プロジェクトに置くものは無い**。`cd <project> && claude` で `/dcc:*` と agent / skill が使える。プロジェクト固有の指示は `AGENTS.md` に書く（`CLAUDE.md` は symlink。`dcc init` が作る）。

既存プロジェクトの `.claude/` との関係は「上書きではなく共存」。plugin は `dcc:` 名前空間なので、プロジェクト独自の command / agent / rules / hook はそのまま並んで動く。ただし旧 `dcc sync` がコピーしたキット由来のファイルが `.claude/commands` 等に残っていると `/code-review` と `/dcc:code-review` が二重に出る。**旧 `dcc init` で作ったプロジェクトでは `dcc init` をもう一度実行する**と移行できる:

- `.claude/` のうちキットが過去に配布したファイル（キット repo の git 履歴で判定）を一覧表示し、確認後に削除する。プロジェクト独自のファイル、`settings.json` から参照されている hook、プロジェクト側で改変されたファイルは残す（改変分は警告のみ。plugin と二重なので不要なら手で消す）
- `.devcontainer/postCreate.sh` をキットの新版（plugin install 入り）に差し替える。改変されていれば上書きせず警告。`devcontainer.json` は触らない
- 何度実行しても安全。確認を省略するなら `dcc init -y`

### devcontainer

```bash
npm install -g @devcontainers/cli
cd <target-project>
dcc init   # .devcontainer/ + AGENTS.md / CLAUDE.md（symlink）を配置
dcc        # devcontainer up + claude 起動
```

コンテナ内の `postCreate.sh` が CLI を `@latest` で入れ、`rules/` / `claude-global/` / `codex-global/` を `~/.claude` `~/.codex` volume に配り、plugin を GitHub（`kiyotan815/dark-claude-code`）から install する。volume は全プロジェクト共有なので一度で済む。

### 他のマシン

フル構成（グローバル `CLAUDE.md` / `rules/` / Codex 用 `AGENTS.md` を含む）にするなら clone して `dcc link-host`。上の host セットアップと同じ挙動（Codex への自動委譲ルール込み）になる:

```bash
git clone https://github.com/kiyotan815/dark-claude-code ~/dark-claude-code
ln -sf ~/dark-claude-code/bin/dcc ~/.local/bin/dcc
dcc link-host
```

command / agent / skill だけでよければ clone 不要で 2 行:

```bash
claude plugin marketplace add kiyotan815/dark-claude-code
claude plugin install dcc@dark-claude-code
```

この場合 `rules/` と `claude-global/CLAUDE.md` は入らないので、Codex 自動委譲の方針は効かない。更新は `claude plugin update dcc@dark-claude-code`（キットの clone がある環境は `dcc sync`）。一時的に試すだけなら `claude --plugin-dir <このリポジトリ>`。

前提:

- Codex への委譲を使うマシンには `codex` CLI と認証（`~/.codex/auth.json` か `OPENAI_API_KEY`）が必要
- リポジトリが private なら、GitHub 経由の install（上の 2 行と devcontainer の postCreate）にそのマシンの GitHub 認証が必要。clone 経由（`dcc link-host`）は clone できれば動く

### dcc サブコマンド

| コマンド | 動作 |
|---|---|
| `dcc` | devcontainer up + claude 起動（`dcc --continue` 等、引数は claude へ透過） |
| `dcc shell` | devcontainer up + bash で入る |
| `dcc up` | コンテナ起動のみ |
| `dcc rebuild` | コンテナ作り直し + claude 起動 |
| `dcc init [-y]` | `.devcontainer/` + `AGENTS.md` / `CLAUDE.md`（symlink）をカレントプロジェクトへ展開。旧 init 済みなら移行（`.claude/` のキット由来コピーを確認の上で削除、`postCreate.sh` 更新）。`-y` で確認省略 |
| `dcc link-host` | host のグローバル設定をキット参照にし、plugin を登録・install |
| `dcc sync` | marketplace と plugin を更新（GitHub 経由で install した環境向け） |
| `dcc kit` | キット repo で claude を起動（改善・PR 作成用） |

認証（volume 永続化なので一度やれば全プロジェクト共有）:

- **Claude**: host に `ANTHROPIC_API_KEY` があれば `remoteEnv` で引き継ぐ。無ければコンテナ内で `claude` を起動してブラウザログイン
- **Codex**: host に `OPENAI_API_KEY` があれば引き継ぐ。ChatGPT アカウントの場合は host の `~/.codex/auth.json` を volume へコピー:

  ```bash
  docker run --rm -v dcc-codex-home:/v -v ~/.codex:/host:ro alpine cp /host/auth.json /v/auth.json
  ```

> イメージは Node 24 固定。Ruby / PHP プロジェクトでは `devcontainer.json` の `image` を差し替える。

## 中身

plugin 名が `dcc` なので、command は `/dcc:<name>`、agent / skill は `dcc:<name>` で参照する。

### command（6）

| コマンド | 用途 |
|---|---|
| `/dcc:codex-flow <タスク>` | 設計 → Codex 委譲実装 → 監査を 1 コマンドで。レビューポイントは設計書ゲートと commit 前 |
| `/dcc:codex-spec <要件>` | Codex 向け設計書を作成（ユニット分割・受け入れ条件・境界・並列マップ） |
| `/dcc:codex-impl <設計書>` | 設計書のユニットを `codex exec` に委譲し、監査まで |
| `/dcc:code-review` | 未コミット差分を `dcc:code-reviewer` でレビュー。要注意差分は `dcc:security-reviewer` へ |
| `/dcc:plan <要件>` | 要件整理・リスク・フェーズ分割。確認を待ってから実装 |
| `/dcc:vuln-fix` | GitHub Security アラート（Dependabot / code scanning / secret scanning）から修正 PR を作る。`--report` は routine 化向き |

### agent（4）

| agent | 役割 |
|---|---|
| `dcc:code-reviewer` | 品質・エラー処理・規約のレビュー |
| `dcc:security-reviewer` | 入力・認証・シークレット・OWASP の観点 |
| `dcc:spec-reviewer` | Codex 委譲前の設計書審査 |
| `dcc:codex-auditor` | Codex 成果物の監査（境界逸脱・受け入れ条件・テスト再実行） |

いずれも `model: inherit`（セッションのモデルを使う）。

### skill（14）

- ワークフロー: `codex-spec` / `codex-delegate` / `commit-helper` / `pr-helper` / `tdd-workflow` / `security-review`
- 規約: `coding-standards` / `backend-patterns` / `frontend-patterns` / `postgres-patterns`、Ruby（`ruby-patterns` / `ruby-testing`）、PHP（`php-patterns` / `php-testing`）

## Claude ⇔ Codex ハイブリッド運用

役割分担: **Claude Code = 司令塔（設計・タスク分割・監査）、Codex = 実行部隊（実装・テスト・環境構築）**。ルーティング基準はグローバル `CLAUDE.md`（`claude-global/CLAUDE.md`）にある。

- 委譲の基本形: `codex exec -s workspace-write -C <dir> -o <最終メッセージ> "$(cat <プロンプト>)" < /dev/null > <進捗ログ> 2>&1 &`。stdin を閉じないと background でハングする。`--dangerously-bypass-approvals-and-sandbox` は使わない
- 作法の全体（background 実行・worktree 並列・統合手順・監査ループ・sandbox 制約）は `skills/codex-delegate`、設計書の書き方は `skills/codex-spec`。3 か月分の運用で学習した instinct（341 件）のうち高信頼のものを 2026-10 に折り込んだ
- プロジェクト指示は `AGENTS.md`（`CLAUDE.md` は symlink）が Claude / Codex の両方に効く
- MCP 方式（従）: `claude mcp add -s user --transport stdio codex -- codex mcp-server`（`mcp-configs/` に定義あり）。ブロッキングでコンテキストも消費するため skill 方式を推奨

## ディレクトリ構成

| パス | 役割 |
|---|---|
| `.claude-plugin/` | `plugin.json`（plugin 名 `dcc`）と `marketplace.json`（marketplace 名 `dark-claude-code`、source はこのリポジトリのルート） |
| `commands/` `agents/` `skills/` | plugin の中身（上記） |
| `hooks/` | opt-in の hook スクリプト（`check-sensitive-paths.sh`）。plugin としては常時有効にしない |
| `rules/` | 共通ルール。plugin には含めず `~/.claude/rules/` へ symlink / コピー |
| `claude-global/` | グローバル設定（`CLAUDE.md` / `settings.json` / `statusline.sh` → `~/.claude/`） |
| `codex-global/` | Codex CLI グローバル設定（`config.toml` / `AGENTS.md` → `~/.codex/`）。`AGENTS.md` は `claude-global/CLAUDE.md` への symlink |
| `mcp-configs/` | MCP サーバ設定例 |
| `scripts/ci/` | agent / command / skill / rule の構造チェック |
| `bin/` | host 側 wrapper `dcc`（plugin 有効時は Bash の PATH にも乗る） |
| `.devcontainer/` | devcontainer 定義 |
| `docs/` `examples/` | Notion Company OS playbook、プロジェクト CLAUDE.md の例 |

## hook

キットは常時有効の hook を持たない。`hooks/check-sensitive-paths.sh`（親ディレクトリ・ホーム・origin 以外への git 操作をブロック）を使いたいプロジェクトだけ `.claude/hooks/` にコピーし、`.claude/settings.json` に登録する:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Read|Edit|Write",
        "hooks": [{ "type": "command", "command": ".claude/hooks/check-sensitive-paths.sh" }]
      }
    ]
  }
}
```

## MCP 注意点

`mcp-configs/mcp-servers.json` は API トークンが必要な MCP（GitHub, Supabase, Vercel など）を含む。プロジェクトで使うときは不要なものを `disabledMcpServers` で無効化し、必要なトークンだけ環境変数で供給する。全 MCP 有効化はコンテキストを圧迫する。

## メンテナンス

- `npm test` = `claude plugin validate .` + 構造チェック + eslint / markdownlint。commit 前に通す
- 使用状況は `/skill-doctor`（skill ごとのトークンコストと未使用）と `claude plugin details dcc@dark-claude-code`（常時コスト）で見る
- 棚卸しは `~/.claude/history.jsonl`（入力履歴、1 年以上残る）と `~/.claude/projects/*/*.jsonl`（直近のセッション記録）で command / Skill / Agent の呼び出し回数を数えて判断する
- 定期実行したいものは routine（`/schedule`）へ。例: `/dcc:vuln-fix --report` を週 1 で回す
- 不要だと感じた command / skill / agent は遠慮なく削除（git 履歴に残る）。大きな変更は branch で試してから main に merge
- upstream を見たいときは `everything-claude-code/`（gitignore 済）を clone する

## カスタマイズ履歴

### 2026-10 棚卸し・plugin 化

- **使用ログで棚卸し**: 1 年分の入力履歴（`~/.claude/history.jsonl`）と直近のセッション記録で command / skill / agent の呼び出し回数を数え、実際に使われていた Codex 一式・code-review・pr-helper 以外を削除。command 29 → 6、agent 15 → 4、差分 103 ファイル・約 1 万行減。メモリ系 3 コマンドは組み込みの auto-memory に置換
- **plugin 化**: `.claude/` へのコピー配布をやめ `dcc@dark-claude-code` として配る。host は `dcc link-host`（ローカルパス marketplace、in-place load）、devcontainer は postCreate が GitHub から install。`npm test` に `claude plugin validate` を追加
- **学習系の回収と廃止**: continuous-learning-v2 が貯めた 341 件の instinct から高信頼の 13 項目（`codex exec` の stdin 閉じ・sandbox での失敗検知・worktree 並列と統合手順・設計書の書き方など）を `codex-delegate` / `codex-spec` / `tdd-workflow` skill に書き戻し、observer と hook を廃止。observer の失敗率と未回収が理由
- **設定の現代化**: agent を `model: inherit` にしてモデル固定を外し、rules からモデル tier 指定を削除。`/dcc:plan` は組み込みの Plan agent を使う。rules とグローバル `CLAUDE.md` を `dcc:` 前提に書き直し、`bin/dcc` の pipefail / grep 境界の不具合を修正

### 2026-04

- 実プロジェクト (p-mill / repohub) から `commit-helper` `pr-helper` 等を逆輸入、Python / Go / Java / Spring / Django / ClickHouse 関連と upstream の assets を削除、Ruby / PHP skill を追加

## ライセンス

MIT (upstream 由来)。`LICENSE` 参照。
