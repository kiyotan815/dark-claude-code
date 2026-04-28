---
description: コードベースの現状を読み取って docs/specs/current-state.md を更新
---

`docs/specs/current-state.md` を最新のコードベースの状態に同期する。

## Step 1: 現状把握

以下を並列で実行:

- `docs/specs/current-state.md` を Read (現在の記載内容)
- `prisma/schema.prisma` を Read (データモデルの現状)
- `src/app/api/` 配下を Glob して API エンドポイント一覧を取得
- `src/app/` 配下のページコンポーネントを Glob (page.tsx)
- `package.json` を Read (依存関係)
- `git log --oneline -20` で直近の変更を確認

## Step 2: 差分検出

以下の観点で `current-state.md` の記載と実際の状態を比較:

| 項目 | 検証方法 |
|------|---------|
| Tech Stack | `package.json` の dependencies と照合 |
| Implemented Features | `src/app/` のページと `src/lib/` の機能モジュールを照合 |
| Data Models | `prisma/schema.prisma` の model 一覧と照合 |
| API Endpoints | `src/app/api/` のルートハンドラを列挙して照合 |
| UI Pages | `src/app/**/page.tsx` を列挙して照合 |
| Known Limitations | コードからは推測しきれないため、既存の記載を維持 (削除しない) |

## Step 3: 更新

差分があれば `docs/specs/current-state.md` を Edit で更新する。新規追加された機能・モデル・API は追記。削除されたものは記載から外す。

`Known Limitations` セクションは慎重に扱う -- コードに無いからといって削除せず、引き続き有効な制約は残す。

## Step 4: 報告

以下を簡潔に報告:
- 追加した項目
- 削除した項目
- 不明だが要確認な項目 (ユーザー判断が必要なもの)
