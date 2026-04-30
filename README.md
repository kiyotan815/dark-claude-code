# dark-claude-code

Claude Code 用の個人テンプレート。
[`affaan-m/everything-claude-code`](https://github.com/affaan-m/everything-claude-code) の fork から派生し、TypeScript / Ruby / PHP 中心の業務向けに curate したもの。

## 方針

- **upstream 非追従** — `everything-claude-code` の更新は自動追跡しない。必要な変更は差分を見て手動取込。
- **使用言語に最適化** — TS / Ruby / PHP に絞り、Go / Java / Spring / Django / Python 関連は削除済み。
- **cp で展開** — plugin としてではなく、各プロジェクトの `.claude/` に `cp` / `rsync` で配る。
- **痛点駆動** — 実使用で困ったら追加・削除。早すぎる最適化はしない。

## デプロイ方法

### 新規プロジェクトに初回展開

```bash
cd <target-project>
mkdir -p .claude
cp -r ~/hackcrackhack/dark-claude-code/{commands,agents,skills,hooks,mcp-configs} .claude/
```

### 既存プロジェクトに更新展開（既存ファイルを守る）

```bash
cd <target-project>
for d in commands agents skills hooks; do
  rsync -av --update ~/hackcrackhack/dark-claude-code/$d/ .claude/$d/
done
```

`--update` でテンプレ側が新しいときだけ上書き。事前確認は `--dry-run` を付ける。

### rules はグローバル配置

`rules/` はプロジェクト個別ではなく `~/.claude/rules/` に置くのが本来の使い方。

```bash
mkdir -p ~/.claude/rules
rsync -av --update ~/hackcrackhack/dark-claude-code/rules/ ~/.claude/rules/
```

## ディレクトリ構成

| パス | 役割 |
|---|---|
| `commands/` | スラッシュコマンド (22) |
| `agents/` | サブエージェント (13) |
| `skills/` | ワークフロー・ドメイン知識 (18) |
| `hooks/` | フックスクリプト (4) |
| `rules/` | 共通ルール (`~/.claude/rules/` へ配置) |
| `mcp-configs/` | MCP サーバ設定例 |
| `scripts/` | command 依存スクリプト (`/setup-pm` `/skill-create` 等) |
| `schemas/` | hook / plugin の JSON スキーマ |
| `contexts/` | dev / research / review のコンテキスト定義 |
| `everything-claude-code/` | 素材庫 (gitignore 済み、参照用 fresh clone) |

## 言語カバレッジ

| 言語 | patterns | testing | 備考 |
|---|---|---|---|
| TS / JS | `coding-standards`, `backend-patterns`, `frontend-patterns` | `tdd-workflow` (汎用) | Node / Express / Next.js / React |
| Ruby | `ruby-patterns` | `ruby-testing` | RSpec 中心、framework-agnostic |
| PHP | `php-patterns` | `php-testing` | PHPUnit 中心、framework-agnostic |

Rails / Laravel 等 framework 特化 skill は必要になったら追加。

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
