---
description: 新規 API エンドポイントを TDD で追加 (Zod 検証 + リポジトリ + テストを生成)
argument-hint: <HTTP method> <path> - <概要> (例: "POST /api/projects/[id]/archive - プロジェクトをアーカイブ")
---

p-mill の規約に沿った新規 API エンドポイントを TDD で追加する。

**追加するエンドポイント:** $ARGUMENTS

## Step 1: 既存パターンの参照

既存の類似エンドポイントを最低1つ Read してパターンを把握する:

- 単純 CRUD: `src/app/api/feedback/route.ts`
- 動的パラメータ + 認可: `src/app/api/projects/[id]/route.ts`
- Slack 連携: `src/app/api/cron/sync/route.ts`

リポジトリパターンの参照:
- `src/lib/repositories/feedback.ts` (シンプル)
- `src/lib/repositories/project.ts` (関連を含む)

バリデーションスキーマ:
- `src/lib/validations/` 配下を Glob して既存パターンを確認

## Step 2: 仕様の明確化

ユーザーに以下を確認 (不明な項目のみ):

- 認証要否 (Supabase Auth セッション必須か、cron Secret か、無認証か)
- リクエストボディ / クエリパラメータのスキーマ
- レスポンス形式 (`{ success: boolean, data?: T, error?: string }` を厳守)
- 副作用 (DB 書き込み、Slack 通知、メール送信など)
- エラーケース (404, 403, 400, 409 等)

## Step 3: テスト先行 (TDD 必須)

以下を **テストから** 書く。実装ファイルはまだ作らない:

1. `src/app/api/.../route.test.ts` (統合テスト)
   - 正常系
   - バリデーションエラー (400)
   - 認証エラー (401/403)
   - リソース未存在 (404)
   - 競合エラー (409 -- 該当する場合)
2. `src/lib/repositories/<entity>.test.ts` (リポジトリ追加メソッドがあれば)
3. `src/lib/validations/<schema>.test.ts` (Zod スキーマがあれば)

`pnpm test <test-file>` を実行して **全テストが失敗することを確認**。

## Step 4: ユーザー承認

「以下のテストを書きました。失敗を確認しました。実装を進めて良いですか?」とユーザーに確認。承認まで実装に進まない。

## Step 5: 実装

承認後、以下を最小限の実装で:

1. `src/lib/validations/<schema>.ts` -- Zod スキーマ
2. `src/lib/repositories/<entity>.ts` -- データアクセス
3. `src/app/api/.../route.ts` -- ルートハンドラ

各ステップでテストが通ることを確認しながら進める。

## Step 6: 検証

- `pnpm tsc --noEmit` -- 型チェック
- `pnpm test` -- 全テスト
- `pnpm lint` -- lint

## 規約 (必須)

- API レスポンスは `{ success: boolean, data?: T, error?: string }` のみ
- 入力は必ず Zod で検証
- 関数 50 行以内
- ファイル 200-400 行 (上限 800)
- イミュータブル (spread で新規作成)
- console.log 禁止 (プロダクション)
- 認可チェックを忘れない (project owner / member / admin の判定)
