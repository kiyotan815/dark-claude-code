# Backlog Issue Workflow

Backlog課題の取得から実装・PR作成・ステータス更新までを一気通貫で行うワークフロー。

## 引数

- `$ARGUMENTS`: Backlog課題キー (例: `PMILL-1`)

## ワークフロー

以下のステップを順番に実行してください。

### Step 1: 課題取得と情報検証

1. `mcp__backlog__get_issue` で `$ARGUMENTS` の課題情報を取得
2. 課題のサマリー、説明、優先度、期限、担当者を表示
3. テンプレートの必須フィールドが埋まっているか検証:
   - **共通**: ゴール、背景・課題、制約条件、受け入れ条件
   - **タスク**: ユーザーストーリー、影響範囲
   - **バグ**: 再現手順、期待動作、実際の動作、影響度
   - **要望**: ユースケース、優先度の根拠
4. 不足があればユーザーにヒアリングし、**全必須フィールドが揃ってから** Step 2 に進む

### Step 2: staging差分の把握とAI壁打ち（複数案生成）

1. `git fetch origin` で最新を取得
2. `git log --oneline main..origin/staging` で **stagingに反映済みだがmainに未マージの変更** を一覧表示し、進行中の機能・修正を把握する
3. 必要に応じて `git diff main..origin/staging -- <関連パス>` で、今回の課題に影響しそうな差分の詳細を確認する
4. コードベースを調査し、課題に関連する既存実装を把握
5. **docs/ コンテキストの確認** -- `docs/README.md` でドキュメント構成を把握 (各 spec エージェントは内部で `docs/strategy/`, `docs/research/`, `docs/specs/current-state.md` を必ず Read する)
6. 以下の **3つのエージェントを並列実行** して仕様案を生成:
   - **spec-simple** (`.claude/agents/spec-simple.md`) - 案A: シンプル・最小実装 (docs/strategy/, docs/specs/current-state.md を参照)
   - **spec-scalable** (`.claude/agents/spec-scalable.md`) - 案B: 拡張性・設計重視 (docs/research/ で将来の拡張方向を確認)
   - **spec-conventional** (`.claude/agents/spec-conventional.md`) - 案C: 既存パターン踏襲 (docs/specs/current-state.md と既存コードを照合)
   - 各エージェントには課題情報（サマリー、説明、受け入れ条件）とコードベースの関連箇所を渡す
   - **staging上の進行中変更との競合・重複リスク** も各エージェントに伝える
   - 各エージェントが docs を引用したかを最終比較表でも反映する (下記参照)
6. 3案の結果を **比較表** にまとめて提示:

```
| 観点 | 案A: シンプル | 案B: 拡張性重視 | 案C: 既存パターン |
|------|-------------|---------------|----------------|
| 概要 | | | |
| DB変更 | | | |
| API変更 | | | |
| UI変更 | | | |
| staging進行中との競合リスク | | | |
| docs整合性 (vision/strategy/research) | | | |
| メリット | | | |
| デメリット | | | |
| 実装規模 | | | |
```

7. **ユーザーが選択** - 案を1つ選択、またはミックス・修正を指示
8. 選択・修正が確定するまでこのステップに留まる

### Step 3: 仕様をBacklogに記載

1. ユーザーが確定した仕様を `mcp__backlog__update_issue` で課題の description に追記（元のテンプレート内容は残す）

### Step 4: 実装 (TDD)

1. `git checkout main && git pull origin main` で最新のmainに切り替え
2. `git checkout -b feat/$ARGUMENTS-<slug>` でブランチ作成
3. 必要に応じてDB スキーマ変更 + `pnpm prisma generate`
4. **テストを先に書く** (RED) - repository, API route, UIコンポーネント
5. テスト実行して失敗確認
6. **実装** (GREEN) - テストが通る最小限のコード
7. テスト実行して全パス確認
8. `pnpm tsc --noEmit` で型チェック
9. `pnpm vitest run` で全テストスイートを実行して既存テストに影響がないことを確認

### Step 5: コミット & PR作成

1. 変更ファイルを `git add` してコミット（conventional commits形式）
2. ユーザーにpushを依頼、またはpush済みか確認
3. `gh pr create --base staging` でstagingブランチ向けにPR作成
4. PR URLをユーザーに表示

### Step 6: Backlog更新

1. `mcp__backlog__update_issue` でステータスを「処理済み」(statusId: 3) に変更
2. コメントにPR URLを記載

## 注意事項

- 各ステップの完了後に次のステップに進む
- Step 1で必須フィールドが不足している場合、ユーザーにヒアリングしてから進む
- Step 2ではstaging上の進行中変更を必ず確認し、競合・重複リスクを仕様案に反映する
- Step 2では3案を比較表で提示し、必ずユーザーの選択・承認を待つこと
- Step 2の各案は並列エージェントで同時生成し、統一フォーマットで出力する
- Step 2の各仕様エージェントは `docs/strategy/`, `docs/research/`, `docs/specs/current-state.md` を必ず Read してから案を作る (各エージェント側に組み込み済み)
- TDDを厳守: テストを先に書き、失敗を確認してから実装
- 全テスト合格 + 型チェック通過を確認してからコミット
- PRは必ず `staging` ブランチに対して作成する（mainへの直接マージは禁止）
