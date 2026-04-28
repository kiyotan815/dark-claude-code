---
description: docs/ を読み込んで機能提案を生成する (戦略・市場調査・現状を踏まえた提案)
argument-hint: [フォーカスしたい領域 (任意): 健全度スコア / 推奨回答 / 良悪コメント抽出 など]
---

p-mill の新機能アイデアを、プロジェクトの戦略・市場調査・現状実装に基づいて提案する。

## Step 1: コンテキスト読み込み

以下のドキュメントを並列で Read する (Task ツールではなく直接 Read):

- `docs/strategy/product-vision.md` -- ミッション、ビジョン、原則
- `docs/strategy/business-strategy.md` -- 現在のフェーズ、優先事項、Build/Skip 判断基準
- `docs/strategy/user-types.md` -- ターゲットユーザーとペルソナ
- `docs/research/market-research-2026-03.md` -- 競合分析、市場ニーズ、ギャップ、優先ロードマップ
- `docs/research/competitive-analysis-2026-04.md` -- 競合詳細プロファイル、機能比較マトリクス、ポジショニング
- `docs/specs/current-state.md` -- 実装済み機能、データモデル、既知の制約

## Step 2: 提案生成

3〜5 個の機能アイデアを提案する。各アイデアについて以下を含める:

- **名前** + 1行サマリ
- **なぜ重要か** -- ビジョン/戦略との整合、ユーザーニーズ、または競合ギャップを引用
- **差別化要因** -- 競合分析の具体的なセクション (例: `competitive-analysis-2026-04.md` セクション 6.2 のカスタマイズ深度) を引用
- **フェーズ適合性** -- `business-strategy.md` の Foundation / Growth / Scale のどれか
- **Build vs Skip 判断** -- `business-strategy.md` のフレームワークを適用
- **リスク** -- プライバシー/労務、ハルシネーション、プラットフォーム依存などから 1 つ具体的に

## 制約

- `docs/specs/current-state.md` に既に実装済みとされる機能は提案しない
- 提案を正当化する際は、ドキュメントのファイル名 + 見出しを必ず引用する
- $ARGUMENTS が指定されている場合、その領域に絞って提案する

## フォーカス領域

$ARGUMENTS
