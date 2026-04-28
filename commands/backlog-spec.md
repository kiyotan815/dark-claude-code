---
description: docs/ を参照して機能仕様を Backlog 課題として起票 (必要なら docs/specs/ にも保存)
argument-hint: <機能名> [- <概要>]
---

p-mill の機能仕様を `docs/` ベースで作成し、Backlog 課題として起票する。

**起票する仕様:** $ARGUMENTS

## Step 1: docs コンテキストの読み込み

以下を **並列で** Read する (省略不可):

- `docs/strategy/product-vision.md`
- `docs/strategy/business-strategy.md`
- `docs/strategy/user-types.md`
- `docs/research/market-research-2026-03.md`
- `docs/research/competitive-analysis-2026-04.md`
- `docs/specs/current-state.md`

## Step 2: Backlog プロジェクト情報取得 (キャッシュなければ)

会話内で既に取得済みなら飛ばす。未取得なら:

- `mcp__backlog__get_project_list` -> PMILL プロジェクトの projectId を特定
- `mcp__backlog__get_issue_types` -> 課題種別一覧 (タスク / バグ / 要望 等の typeId)
- `mcp__backlog__get_priorities` -> 優先度 ID (高 / 中 / 低)

## Step 3: 重複起票チェック

`mcp__backlog__get_issues` で類似タイトルの既存課題がないか確認 (キーワード検索)。あれば該当課題 URL を提示し、起票を続行するかユーザーに確認。

## Step 4: 仕様ドラフト作成

以下のテンプレートで本文を作成 (Backlog は markdown 表記対応):

```markdown
## 概要

[1-2 行の要約]

## Why

- 解決する課題: [user-types.md または current-state.md の該当箇所を引用]
- ビジョン整合: [product-vision.md の原則を引用]
- 競合差別化: [market-research-2026-03.md / competitive-analysis-2026-04.md からの引用]

## Who

- 主要ユーザータイプ:
- 利用シーン:

## What

ユーザー視点の振る舞い:
- ...

スコープ外:
- ...

## How (技術スケッチ)

- データモデル / スキーマ変更:
- API エンドポイント:
- UI 画面:
- AI / プロンプト変更:

## Risks

- プライバシー/労務:
- ハルシネーション対策:
- プラットフォーム依存:

## Acceptance Criteria

- [ ] ...

## Phase

Foundation / Growth / Scale (`business-strategy.md` 基準)

## Open Questions

- ...

---

参考ドキュメント (リポジトリ内):
- docs/strategy/product-vision.md
- docs/research/competitive-analysis-2026-04.md セクション X
- docs/specs/current-state.md
```

**重要:** Backlog 課題は GitHub リポジトリ context 外で閲覧されるため、`docs/` への相対リンクは効かない。**ファイルパス + セクション名を文字列として残す**。

## Step 5: ユーザー承認

起票前に以下を提示し承認を得る:

| 項目 | デフォルト |
|------|-----------|
| Summary (件名) | `[Spec] <機能名>` |
| Description (本文) | Step 4 のドラフト |
| Issue Type | タスク (確認: タスク / 要望 / バグ / その他) |
| Priority | 中 (確認: 高 / 中 / 低) |
| Assignee | 未割当 (確認: ユーザー指定があれば設定) |
| Parent Issue | なし (epic 配下に置く場合は確認) |

承認まで `mcp__backlog__add_issue` を呼ばない。

## Step 6: Backlog に起票

`mcp__backlog__add_issue` で起票:

```
projectId: <Step 2 で取得した PMILL の projectId>
summary: <Step 5 で確定した件名>
description: <Step 5 で確定した本文>
issueTypeId: <タスク等の typeId>
priorityId: <中等の priorityId>
assigneeId: <省略可>
```

起票後、レスポンスから課題 URL (またはキー、例: `PMILL-XX`) を取得してユーザーに報告。

## Step 7: docs/specs/ への保存確認

「この仕様を `docs/specs/` にも保存しますか?」と確認。

保存する場合:
- ファイル名: `docs/specs/<kebab-case-機能名>.md`
- 内容: Step 4 のテンプレート + Backlog 課題 URL を冒頭に追記
- `write-spec` command と同じテンプレートを踏襲

## 制約

- **必ずユーザー承認後に起票する** -- 自動起票しない
- **docs を読まずに起票しない** -- Step 1 を必ず実行
- **重複チェックを省略しない** -- Step 3 を必ず実行
- 起票内容に個人情報・シークレットを含めない
- 提案する仕様は `docs/specs/current-state.md` の既存実装と矛盾しない (拡張・変更なら明示)
- `docs/specs/` への保存は任意 (Backlog が一次ソース、docs はミラー)
