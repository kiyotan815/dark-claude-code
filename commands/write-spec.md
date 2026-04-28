---
description: 機能仕様書を docs/specs/ に書き出す (docs/ を参照して根拠付きで)
argument-hint: <機能名> [- <概要>]
---

p-mill の機能仕様書を作成する。

**要求された機能:** $ARGUMENTS

## Step 1: コンテキスト読み込み

以下を並列で Read する:

- `docs/strategy/product-vision.md`
- `docs/strategy/business-strategy.md`
- `docs/strategy/user-types.md`
- `docs/research/market-research-2026-03.md` (差別化の参照)
- `docs/research/competitive-analysis-2026-04.md` (競合ポジショニング)
- `docs/specs/current-state.md` (既存機能との重複回避、統合点の把握)

## Step 2: 機能の理解

$ARGUMENTS が曖昧な場合は、仕様書を書く前に 1 ラウンドの確認質問をする。明確な場合は次へ。

## Step 3: 仕様書の作成

`docs/specs/<kebab-case-機能名>.md` に以下の構造で新規ファイルを作成する:

````markdown
# <機能名>

## Why (なぜ作るか)
- 解決する課題 (`user-types.md` のペルソナまたは `current-state.md` の既知制約を引用)
- ビジョン整合 (`product-vision.md` の原則を引用)
- 競合文脈 (`research/` から該当箇所を引用)

## Who (ターゲット)
- 主要ユーザータイプ
- 利用シーン

## What (機能内容)
- ユーザー視点の振る舞い (5〜10 個の箇条書き)
- スコープ外 (作らないもの)

## How (技術スケッチ)
- 新規データモデル / スキーマ変更
- 新規 API エンドポイント
- 新規 UI 画面
- AI / プロンプト変更 (該当する場合)

## Risks (リスク)
- プライバシー/労務 (`market-research-2026-03.md` セクション 4 参照)
- ハルシネーション対策 (`competitive-analysis-2026-04.md` セクション 8.2 参照)
- プラットフォーム依存
- その他

## Acceptance Criteria (受け入れ基準)
- 「完成」とみなす具体的なチェックリスト

## Phase
- Foundation / Growth / Scale (`business-strategy.md` 基準)

## Open Questions
- 未解決の論点
````

## Step 4: 報告

ユーザーに以下を伝える:
- 作成した仕様書のパス
- 主要な決定事項 (フェーズ、リスク、差別化ポイント) のサマリ

## 制約

- 仕様書には根拠としたドキュメントへの相対リンクを必ず含める
- コード実装はしない -- これは仕様策定のみ
- `settings.json` の Write hook が `.md` ファイル作成をブロックする場合がある。ブロックされたら、ユーザーに `docs/specs/` をフック例外に追加するよう依頼する
