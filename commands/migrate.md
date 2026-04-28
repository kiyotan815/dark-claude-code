---
description: Prisma マイグレーションを安全運用ルール (docs/guides/database-migration.md) に従って作成・実行
argument-hint: <変更内容の簡潔な説明 (例: "PoorResponse に severity 列を追加")>
---

p-mill の DB マイグレーションを `docs/guides/database-migration.md` の運用ルールに従って計画・作成する。

**変更内容:** $ARGUMENTS

## Step 1: 運用ルール再確認

`docs/guides/database-migration.md` を Read する (毎回。記憶に頼らない)。

## Step 2: 変更内容の分類

以下の質問に答えて分類を確定:

1. 変更タイプ
   - `CREATE TABLE` (新規テーブル)
   - `ALTER TABLE ADD COLUMN` (列追加)
   - `ALTER TABLE DROP COLUMN` (列削除 -- 推奨されない)
   - `CREATE INDEX` (インデックス追加)
   - `ALTER TABLE ADD CONSTRAINT` (制約追加)
   - その他

2. 対象テーブルのサイズ目安
   - 大規模 (Message など数百万行) -> 単独マイグレーション必須
   - 中規模 / 小規模

3. 同一マイグレーション内に複数 DDL が混在しないか
   - `CREATE TABLE` と `ALTER TABLE` は **必ず別ファイル** にする
   - 違反していれば分割を提案

## Step 3: マイグレーションファイル作成

`prisma/schema.prisma` を編集してから `pnpm prisma migrate dev --create-only --name <kebab_case_name>` を実行する想定の SQL ファイルを `prisma/migrations/<timestamp>_<name>/migration.sql` として下書きする。

**必須プリアンブル (冒頭2行):**

```sql
SET LOCAL statement_timeout = 0;
SET LOCAL lock_timeout = '10s';
```

**推奨しないパターンを検出したら警告:**
- `NOT NULL` 列の一括追加 (DEFAULT 無し) -> 段階移行を提案
- `DROP COLUMN` / `DROP TABLE` -> コード参照削除 + 次回リリースで DROP を提案
- 複数テーブルの破壊的変更を 1 ファイルに

## Step 4: チェックリスト検証

以下を全て確認しユーザーに報告:

- [ ] `ALTER` と `CREATE TABLE` が混在していない
- [ ] 冒頭に `SET LOCAL statement_timeout = 0;` `SET LOCAL lock_timeout = '10s';`
- [ ] 大規模テーブルへの破壊的変更は単独マイグレーション
- [ ] cron 実行時間帯 (UTC 00:00-00:30) と被らないマージ計画
- [ ] ロールバック可能か (DROP COLUMN 等は避ける)

## Step 5: マージ時間帯の提案

ユーザーの現在時刻 (JST) を考慮し、推奨マージ時間帯 (UTC 01:00 以降 = JST 10:00 以降) を提案。すぐマージ予定なら現在時刻が cron 帯と被らないか確認。

## Step 6: 復旧情報の事前共有

万が一失敗した場合に備え、以下を提示:
- 失敗時は GitHub Actions -> Database Migration -> Run workflow で `resolve-rolled-back` または `resolve-applied` を選択
- エラーコード対処表 (P3018 / P1002 / P1017) は `docs/guides/database-migration.md` セクション 5 参照
- ロック保持者特定の SQL は同セクション 5.3 参照

## 制約

- スキーマ変更を勝手にコミット・push しない
- `pnpm prisma migrate deploy` の実行はユーザー承認後
- migration.sql に SET LOCAL がなければ作成し直す
