# Notion Company OS × Claude Code Playbook

> 個人開発・新規事業を「ゴール逆算」で運用するための、Notion ベース PM システムと Claude Code 統合のセットアップ Playbook。  
> 別の Claude Code セッション（または別プロジェクト）にそのまま渡せば、同じ仕組みが再現できるよう設計してある。

---

## 1. このドキュメントは何か

「年内にβリリース」「半年で売上◯円」のような **長期ゴールを起点に、日々のタスクまで一気通貫で運用する** ための仕組みと、それを Claude Code から操作する統合構成の完全ガイド。

具体的には：

1. Notion 上に「Company OS」と呼ぶダッシュボードと 4 つのデータベース（Projects / Initiatives / Tasks / Inbox）を構築
2. Claude Code に Notion MCP を接続し、メモリ・CLAUDE.md・Slash Commands で操作を高速化
3. ゴール逆算で Initiative を設計、Phase 分解、Tasks への落とし込みまでを対話で進められる状態にする

このドキュメントは **読み物** であると同時に **実行可能なレシピ** でもある。第 7 章の Bootstrap Prompt を新しい Claude セッションに渡せば、同じ構造が再現される。

---

## 2. なぜこの仕組みか（メリット）

### 個人開発・スモールチームに最適化された情報密度

- **意思決定が記録に残る**: Initiative の Outcome、Phase 移行のタイミング、Task の Due 決定理由がすべて Notion に堆積する。週次レビュー時の「何を決めたか思い出せない問題」が消える
- **キャプチャと整理を分離**: 思いついた瞬間は Inbox に投げるだけ。整理は週1。アイデアを取り逃がさず、かつ取り扱いに圧倒されない

### Claude Code 経由の操作で運用負荷が激減

- **「STG構築タスクに手順書を書いて」「無料/有料境界線決定の Due を1週間前倒し」など、対話一発で複雑な構造操作ができる**
- Notion のフォームクリック / プロパティ設定 / リンクドビュー作成の手間がない
- 複数 DB をまたぐ一括操作（Initiative 新規 + Tasks 5件投入 + 既存 Tasks のリンク張り替え）が秒で終わる

### ゴール逆算が自然に強制される

- 「Task を切る前に Initiative がないとリンクできない」「Initiative を作る前に Outcome が空白だと作れない（運用ルール）」など、構造が逆算を促す
- 「なんとなくやる」「目的のない作業」が物理的に置き場所がない

### 別プロジェクト・別 Claude でも再現性が高い

- ID とスキーマと運用ルールが言語化されているため、別ドメイン（個人開発の別プロダクト、業務改善プロジェクト、副業案件）にコピーできる
- Markdown のみで配布可能、ベンダーロックなし

---

## 3. 全体像

```
┌──────────────────────────────────────────────────────┐
│                    Company OS (Notion)               │
│   🔥 進行中 / 直近7日 / プロジェクト別 / ロードマップ / Inbox    │
└─────────┬──────────┬──────────┬──────────┬──────────┘
          │          │          │          │
     ┌────▼───┐ ┌────▼─────┐ ┌──▼───┐ ┌────▼────┐
     │Projects│ │Initiatives│ │Tasks │ │  Inbox  │
     │ （会社）│ │ （会社）  │ │（会社）│ │ （会社） │
     └────────┘ └──────────┘ └──────┘ └─────────┘
          ▲          ▲          ▲          ▲
          └──────────┴──────────┴──────────┘
                        │
                ┌───────▼────────┐
                │  Claude Code   │
                │ + Notion MCP   │
                │ + Slash Cmds   │
                │ + Memory       │
                └────────────────┘
```

- **Projects**: 会社全体で動かしているプロダクト/施策（粒度大）
- **Initiatives**: Project を進めるための時間制約付き取り組み（Outcome 必須、Phase で進行管理）
- **Tasks**: 1日〜数日で終わる実作業（必ず Initiative に紐付く）
- **Inbox**: 思いつきの一次保管（週1で仕分け）

---

## 4. 設計思想：ゴール逆算の事業運営

### 4.1 ゴール → Initiative

長期ゴール（例: 「年内に有料ユーザー検証を完了」）を **Initiative** として書き出す。3 つの必須要素：

| 要素 | 役割 | 書けないとどうなる |
|---|---|---|
| **Outcome** | 計測可能な完了条件 | 「やった気になる」が起きる |
| **Target date** | いつまでに | 永遠に着手されない |
| **Phase** | 今どこにいるか | 全体感がブレる |

**Outcome が書けない Initiative は Inbox に戻して寝かせる**。「なんとなく必要そう」を許さない。

### 4.2 Initiative → Phase 分解

`Discovery → Plan → Build → Launch → Improve` の 5 フェーズで進行管理。

Initiative の Notes 欄に **Target date から逆算したマイルストーン日** を書いておく：

```
Discovery 〜YYYY-MM-DD : やる/やらない判断完了
Plan      〜YYYY-MM-DD : スコープ・設計確定
Build     〜YYYY-MM-DD : 実装完了
Launch    〜YYYY-MM-DD : リリース
Improve   YYYY-MM-DD〜 : 振り返り・改善
```

### 4.3 Phase → Tasks 起票

Tasks は **「直近フェーズを進めるための具体作業」のみ**。

- Build フェーズ中なら、Build に必要な Tasks を切る
- 先のフェーズ用 Tasks は切らない（変動するため）
- Task の Due は Phase の締切以前

### 4.4 Inbox first

思いつき・依頼・ふと浮かんだアイデアは全部 **Inbox に投げる**。

- Kind（Task/Memo/Idea）は迷ったら空欄でOK
- 投入時に「Task に昇格させますか？」とは聞かない（運用ルール）
- 週1回まとめて `/triage` で仕分け

理由: キャプチャ時に整理を要求すると入力が止まり、結局メモを別の場所に分散させてしまう。

---

## 5. Notion 構造

### 5.1 Projects（会社）

会社全体で動かしているプロダクト・施策。粒度は大きく、年単位で続くもの。

| プロパティ | 型 | 用途 |
|---|---|---|
| Name | title | プロジェクト名 |
| Type | Select (Product, Internal) | 顧客向けか社内向けか |
| Status | Select (Active, Paused, Done) | 稼働状況 |
| Notes | Text | 短い説明 |

逆向きリレーション: Initiatives / Tasks / Inbox items

### 5.2 Initiatives（会社）

Project を推進する、時間制約付きの取り組み。

| プロパティ | 型 | 用途 |
|---|---|---|
| Title | title | 施策名 |
| Project | Relation→Projects (DUAL) | 上位プロジェクト |
| Phase | Select (Discovery, Plan, Build, Launch, Improve) | 進行段階 |
| Status | Select (Not started, In progress, Done) | 進行ステータス |
| Priority | Select (High, Mid, Low) | 優先度 |
| Target date | Date | ゴール日 |
| Outcome | Text | **計測可能な完了条件**（必須） |
| Notes | Text | 逆算スケジュール、依存関係など |

逆向きリレーション: Tasks

ビュー:
- **Roadmap** (Timeline by Target date)
- **By Project** (Table, GROUP BY Project)

### 5.3 Tasks（会社）

実作業。Initiative に必ず紐付く。

| プロパティ | 型 | 用途 |
|---|---|---|
| Title | title | 作業名 |
| Project | Relation→Projects (DUAL) | 上位プロジェクト |
| Initiative | Relation→Initiatives (DUAL) | 紐付き施策 |
| Status | Select (Not started, In progress, Blocked, Done) | ステータス |
| Due | Date | 期日 |
| Priority | Select (High, Mid, Low) | 優先度 |
| Tags | Multi-select (Dev, Biz, Design, Ops) | 担当軸 |
| Notes | Text | 補足、手順、判断材料 |

ビュー:
- **進行中** (Table, FILTER Status = "In progress", SORT Due ASC) ← 日々これを見る
- **直近7日** (Table, FILTER Due within next 7 days AND Status != Done)
- **By Project** (Table, GROUP BY Project)
- **Board** (Board, GROUP BY Status)

### 5.4 Inbox（会社）

思いつきの一次保管。

| プロパティ | 型 | 用途 |
|---|---|---|
| Title | title | 内容 |
| Kind | Select (Task, Memo, Idea) | 仕分け時に決める |
| Project | Relation→Projects (DUAL) | 紐付き（任意） |
| Processed | Checkbox | 仕分け済みフラグ |
| Created | CREATED_TIME | 投入日時 |

ビュー:
- **Unprocessed** (Table, FILTER Processed = false, SORT Created DESC)

### 5.5 ダッシュボード（Company OS）

親ページに linked view を順番に配置：

```markdown
## 🔥 進行中           ← Tasks: Status = In progress（日常の本拠地）
## 直近7日             ← Tasks: Due within 7 days, Status != Done
## プロジェクト別タスク  ← Tasks: GROUP BY Project
## ロードマップ        ← Initiatives: Timeline by Target date
## 未仕分け（Inbox）   ← Inbox: Unprocessed
```

**「🔥 進行中」を先頭に置くのが重要**。「今やってる仕事」が常に上に見える状態を作る。

---

## 6. Claude Code 統合

### 6.1 メモリ（reference type）

Notion の ID/URL を `memory/reference_notion.md` に保存：

```markdown
---
name: notion-company-os-ids
description: Company OS の Notion ID リファレンス
metadata:
  type: reference
---

## Company OS
- Page URL: https://www.notion.so/<page_id>
- Page ID: <page_id>

## Databases
| DB | Database ID | Data Source ID |
|---|---|---|
| Projects（会社） | xxx | yyy |
...

## スキーマ要点・操作上の注意
- Status / Phase は SELECT 型
- Relation は JSON 配列文字列 `"[\"https://...\"]"`
- Date は expanded property `"date:Due:start": "YYYY-MM-DD"`
- Checkbox は `"__YES__"` / `"__NO__"`
```

これがあると新しいセッションでも「Inbox に追加」が即動く。

### 6.2 CLAUDE.md

プロジェクト直下に置き、Notion 運用ルールを明文化：

```markdown
# <プロジェクト名>

## プロジェクト管理: Notion Company OS

タスク・施策・ロードマップは Notion の Company OS で一元管理。Notion 操作は Claude Code 経由。

- Company OS: https://www.notion.so/<page_id>
- ID リファレンスは memory の reference_notion.md

## Notion 運用ルール

### Inbox first
思いついたタスクは Inbox に投入。週1で /triage 仕分け。

### Tasks には必ず Initiative を紐付ける
紐付かない Task は Inbox に戻す。

### Initiative の Outcome は計測可能に
書けない Initiative は Inbox に戻して寝かせる。

### 日付は絶対参照
「来週」「明日」は YYYY-MM-DD に解決して保存。

### Notion ↔ memory の整合性
重要な変更は memory にも追従。
```

### 6.3 settings.local.json（権限）

`.claude/settings.local.json`：

```json
{
  "permissions": {
    "allow": [
      "mcp__notion__notion-fetch",
      "mcp__notion__notion-search",
      "mcp__notion__notion-get-users",
      "mcp__notion__notion-get-comments",
      "mcp__notion__notion-get-teams",
      "ReadMcpResourceTool",
      "ListMcpResourcesTool"
    ]
  }
}
```

**読み取りは auto-allow、書き込みは都度確認** の方針。「今日やる見せて」「ロードマップ確認」が瞬時に動く。

### 6.4 Slash Commands

`.claude/commands/` に：

- **`/inbox <内容>`** — Inbox に1件投入（深く考えない）
- **`/today`** — 進行中タスクを表示・start/done/move で更新
- **`/triage`** — Inbox 未処理を対話的に Tasks / Initiatives へ昇格
- **`/notion-ticket [URL or ID]`** — Notion Task から仕様策定 → 3案並列生成 → 採用案を Task に書き戻し → TDD 実装 → PR 作成 → Task を Done にするまでの一気通貫フロー

詳細は第 7 章 Bootstrap Prompt に含まれる。

`/notion-ticket` は p-mill プロジェクトの `/backlog`（Backlog 課題ベース）を Notion 用に逆輸入したもの。仕様を「考える人」と「書く人」と「実装する人」を分けて段階的に進めるのが利点で、特に Initiative の Outcome に対する貢献度を 3 案比較で意識できる。

---

## 7. セットアップ手順

### 7.1 前提条件

- Notion ワークスペースに Claude のインテグレーションを追加済み（Notion MCP が動く状態）
- Claude Code が動く環境
- プロジェクト固有のワーキングディレクトリ

### 7.2 Bootstrap Prompt

新しい Claude Code セッションを開き、下記をそのまま貼り付ける：

````markdown
あなたは Notion MCP を経由して Notion を操作できる Claude Code セッションです。
これから、新規事業を「ゴール逆算」で運用するための Notion ベース PM システムを構築してください。

## ゴール

以下の4つのデータベースと、それらをまとめるダッシュボードページ「Company OS」を Notion に作成し、Claude Code から操作できるよう設定する。

## 1. Company OS（親ダッシュボードページ）

- ページ名: `Company OS`
- アイコン: 🏢
- 場所: ワークスペース直下（page_id 指定なし）
- 本文: 運用ルールの短い説明

## 2. Projects（会社）データベース

スキーマ:
- Name (TITLE)
- Type (SELECT: Product=blue, Internal=gray)
- Status (SELECT: Active=blue, Paused=yellow, Done=green)
- Notes (RICH_TEXT)

説明: 「会社で動かしているプロジェクトの一覧。Product / Internal で分類。」

初期データ（必要に応じてユーザーに聞いて差し替え）:
- 例: 自社プロダクト A / Product / Active
- 例: 自社プロダクト B / Product / Active
- 例: 業務効率化 / Internal / Active

## 3. Initiatives（会社）データベース

スキーマ:
- Title (TITLE)
- Project (RELATION → Projects DUAL)
- Phase (SELECT: Discovery=gray, Plan=blue, Build=purple, Launch=orange, Improve=green)
- Status (SELECT: Not started=default, In progress=blue, Done=green)
- Priority (SELECT: High=red, Mid=yellow, Low=gray)
- Target date (DATE)
- Outcome (RICH_TEXT)
- Notes (RICH_TEXT)

説明: 「プロジェクトを推進する施策単位。Outcome は計測可能に。」

ビュー:
- Roadmap (Timeline by Target date)
- By Project (Table, GROUP BY Project)

## 4. Tasks（会社）データベース

スキーマ:
- Title (TITLE)
- Project (RELATION → Projects DUAL)
- Initiative (RELATION → Initiatives DUAL)
- Status (SELECT: Not started=default, In progress=blue, Blocked=red, Done=green)
- Due (DATE)
- Priority (SELECT: High=red, Mid=yellow, Low=gray)
- Tags (MULTI_SELECT: Dev=blue, Biz=orange, Design=pink, Ops=gray)
- Notes (RICH_TEXT)

説明: 「日々のタスクを集約。Initiative に必ず紐付ける。」

ビュー:
- 進行中 (Table, FILTER `Status` = `In progress`, SORT BY `Due` ASC, `Priority` ASC)
- 直近7日 (Table, FILTER `Status` != `Done` AND `Due` is within next 7 days, SORT BY `Due` ASC)
  ※ DSL に相対日付がない場合は、当日と7日後の絶対日付でハードコードし、後で UI で相対日付に切り替える旨を案内する
- By Project (Table, GROUP BY Project, SORT BY Due ASC)
- Board (Board, GROUP BY Status)

## 5. Inbox（会社）データベース

スキーマ:
- Title (TITLE)
- Kind (SELECT: Task=blue, Memo=gray, Idea=yellow)
- Project (RELATION → Projects DUAL)
- Processed (CHECKBOX)
- Created (CREATED_TIME)

説明: 「まずここに全部入れる。週1で /triage 仕分け。」

ビュー:
- Unprocessed (Table, FILTER `Processed` = false, SORT BY `Created` DESC)

## 6. Company OS 本文にリンクドビューを配置

順番:
```
## 🔥 進行中           → Tasks の進行中ビュー
## 直近7日             → Tasks の直近7日ビュー
## プロジェクト別タスク  → Tasks の By Project ビュー
## ロードマップ        → Initiatives の Roadmap ビュー
## 未仕分け（Inbox）   → Inbox の Unprocessed ビュー
```

## 7. メモリに ID リファレンス保存

作成完了後、Company OS / 各 DB / Data source の ID と URL を `memory/reference_notion.md` に保存する（type: reference）。MEMORY.md にも索引行を追加。

## 8. プロジェクト直下に CLAUDE.md 作成

Notion 運用ルール（Inbox first / Initiative 必須 / Outcome 計測可能 / 絶対日付 / memory 追従）を明文化。

## 9. .claude/settings.local.json で Notion 読み取り auto-allow

```json
{
  "permissions": {
    "allow": [
      "mcp__notion__notion-fetch",
      "mcp__notion__notion-search",
      "mcp__notion__notion-get-users",
      "mcp__notion__notion-get-comments",
      "mcp__notion__notion-get-teams",
      "ReadMcpResourceTool",
      "ListMcpResourcesTool"
    ]
  }
}
```

## 10. Slash Commands を4つ作成

`.claude/commands/` に以下を作成:

### inbox.md
`/inbox <内容>` で Inbox に1件投入。Kind や Project を引数で受け取れる。Notion MCP の create-pages を使い、Inbox データソースに作成。

### today.md
`/today` で Tasks の「進行中」ビュー相当を表示。`done` / `start` / `move` 引数で更新可能。

### triage.md
`/triage` で Inbox 未処理を対話的に取り出し、Task に昇格 / Initiative に昇格 / Memo として保持 / 削除 / スキップ の選択肢でユーザーと進める。

### notion-ticket.md
`/notion-ticket [URL or ID]` で Notion Task から仕様策定 → 実装 → PR までを一気通貫。フロー:

1. Notion Task 取得（引数省略時は進行中タスクから選択）
2. 必須情報の検証（ゴール / 受け入れ条件 / 制約条件 / 影響範囲）→ 不足ならヒアリング
3. 既存実装把握（git log / 関連ファイル読み込み）
4. **3 spec エージェントを並列実行**（`spec-pragmatic` / `spec-architect` / `spec-ux`）
5. 比較表を提示 → AskUserQuestion で採用案を選ばせる
6. 採用案を Notion Task body に書き戻し + Status = In progress
7. TDD で実装（テスト先行 → 実装 → 型チェック → リント）
8. conventional commits でコミット → main ブランチへ PR 作成
9. Notion Task の Status = Done に更新 + PR URL を body に追記

**前提**: `spec-pragmatic` / `spec-architect` / `spec-ux` の 3 エージェントが `~/.claude/agents/` または `.claude/agents/` に存在すること。なければ用意するか、`/notion-ticket` 内で別の方法（plan agent 等）で 3 案生成するよう調整する。

## 完了時のレポート

すべて完了したら、作成した親ページ・各DB のリンクと、`/inbox` `/today` `/triage` `/notion-ticket` の使い方をまとめて返す。

## 注意事項

- Notion MCP の DDL は STATUS 型のオプション値を直接定義できない。Status カラムは SELECT 型で代用する
- ビュー DSL は相対日付（TODAY、WITHIN）未対応。「直近7日」は当日基準の絶対日付でハードコードし、ユーザーに UI 切替を案内
- リレーションは DUAL を必ず付けて双方向にする
- 各 DB の description には日本語で短い運用メモを入れる
````

### 7.3 手動セットアップ手順（プロンプト渡しが使えない場合）

1. Notion で「Company OS」ページを作成（🏢）
2. その配下に 4 つの DB を上記スキーマで作成
3. 各 DB のビューを設定
4. 親ページに linked view を順番に追加
5. CLAUDE.md / settings.local.json / Slash Commands は本ドキュメントから手動コピー
6. Notion ID をメモリにメモ

---

## 8. 運用フロー

### 8.1 日次（朝5分・夜2分）

**朝**:
1. Company OS を開く（または Claude Code で `/today`）
2. 🔥 進行中ビューを眺める
3. 今日の本命を1つ決める

**夜**:
1. 終わった Task を Done に（`/today done <名前>`）
2. やり残しは Due を翌日へ（`/today move <名前> <日付>`）

### 8.2 週次（金曜15分）

1. Claude Code で `/triage` を打つ
2. Inbox 未処理を上から仕分け：
   - Task に昇格 → Initiative 紐付け必須
   - Initiative に昇格 → Outcome 必須
   - Memo として保持
   - 削除
3. 残った Tasks の Due を見直し

### 8.3 月次（30分）

1. ロードマップビューで Initiatives の進行確認
2. 遅延 Initiative の Phase 移行可否を判断
3. 次月にやる Initiative を Phase=Discovery で起こす
4. メモリ `project_overview.md` を最新化

---

## 9. 落とし穴と回避策

### 9.1 STATUS 型 vs SELECT 型

Notion MCP の DDL は **STATUS 型のオプション値を直接定義できない**（自動で「未着手 / 進行中 / 完了」が入る）。  
→ SELECT 型で代用（Active/Paused/Done など好きな値を指定可）。Board ビューも SELECT で問題なく動く。

### 9.2 相対日付フィルタ

ビュー DSL に `TODAY` / `WITHIN NEXT 7 DAYS` のような相対日付はない。  
→ 作成時は絶対日付でハードコード、Notion UI で「is on or before today」等に手動切替するよう案内。

### 9.3 リレーション値の渡し方

ページ作成時の Relation プロパティは **JSON 配列文字列**で渡す：

```json
"Project": "[\"https://www.notion.so/365b8c6e...\"]"
```

URL のエスケープを忘れない。

### 9.4 仕分け疲れ

`/triage` で 10 件以上溜まると気が滅入る。  
→ 5 件以上なら最初に件数を伝え、「今日全部やる / N件だけ」を選ばせる UX を Slash Command 側に組み込む。

### 9.5 Outcome 書けない Initiative

「なんとなく重要」な Initiative ほど Outcome が書けない。  
→ 書けないものは Inbox に戻して寝かせる。1〜2 週間後に再挑戦すると書けることが多い。

---

## 10. 実例: 絵本AI 2026年ロードマップ

「年内に有料ユーザー検証完了」を起点に逆算した実例。

### 10.1 ゴール設定

```
Outcome: 2026/12/31 までに、有料プランで課金完了ユーザー1名以上、
         または「課金しない理由」がユーザー5名以上のヒアリングで
         テーマ別に言語化されている。
```

### 10.2 3段ロケット構造

```
① 社内検証 (〜6/30)        クローズド・無料・フル機能
       ↓ フィードバック反映
② 一般リリース (7/15公開)    無料先行 + Early Adopter 永久優遇
       ↓ 利用データ蓄積
③ 課金検証 (8/15課金導入〜12/31)  有料プラン投入 → 4.5ヶ月の検証
```

ポイント:
- ターゲットが子持ち親なので「サポーター/応援」型はミスマッチ → 機能差別のフリーミアム
- bait-and-switch 回避のため、LP に課金導入予告を明記 + Early Adopter 永久優遇
- 課金検証期間を 4.5 ヶ月確保（設計 → 投入 → 検証 → 改善のサイクル余裕）

### 10.3 Tasks の落とし込み

① 社内検証フェーズには、社内メンバー募集 / 生成品質確認 / アナリティクス組み込み / クローズド環境構築 / フィードバック収集仕組み / 振り返りの 6 件をぶら下げる。

② 一般リリースフェーズには、オンボーディング最適化 / LP・規約 / Early Adopter フラグ実装 / ユーザー獲得チャネル準備 の 4 件。

③ 課金検証フェーズには、無料期間データ分析 / 2週間前アナウンス / 境界線決定 / 有料プラン機能セット / 課金フロー実装 の 5 件。

各 Task は Initiative の Phase 締切以前に Due を設定し、横串で「次に何をやるか」が `/today` で見えるようにする。

---

## 11. カスタマイズ余地

このベースから派生させやすい拡張：

| 拡張 | 用途 |
|---|---|
| **Goals DB** | 半期/年単位の大目標を Initiative の上位に置く（複数 Initiative が1 Goal にぶら下がる） |
| **OKR 化** | Initiative の Outcome を Objective + Key Results に展開 |
| **Decisions DB** | 重要な意思決定を別 DB で記録（ADR 的に） |
| **Retros DB** | 月次/四半期 Retrospective を Initiative に紐付け |
| **People DB** | 関与者・ステークホルダー（チームメンバー、外部協力者）の Relation |
| **Budgets** | Initiative ごとの予算管理（数値プロパティ） |
| **Hooks** | Claude Code の Stop hook で「今日 Done にした Tasks 件数」を slack/メールへ |

---

## 12. 関連リンク

- Notion MCP (Anthropic): <https://github.com/anthropics/anthropic-quickstarts/tree/main/notion-mcp>
- Notion API Docs: <https://developers.notion.com/>
- このプロジェクトの Company OS: <https://www.notion.so/365b8c6e3a558150a515fa6a4c9567dd>
- 絵本AI ロードマップ詳細: `docs/business/07-roadmap.md`

---

## 付録: メモリ運用の Tips

Claude Code のメモリ（`~/.claude/projects/<project>/memory/`）は **ファイルベースで永続化**される。Notion 構造の補完として：

- **`reference_notion.md`** (type: reference) — Notion ID 集約
- **`project_overview.md`** (type: project) — 現在のロードマップ・主要 Initiative の要約（Notion で変更があったら追従）
- **`feedback_working_style.md`** (type: feedback) — ユーザーの好みの進め方
- **`user_profile.md`** (type: user) — ユーザーの役割・専門性

これらは新セッション開始時に Claude が自動参照するため、「前回どこまで進んだか」を毎回説明する必要がない。

メモリの命名規則: `<type>_<topic>.md`。`MEMORY.md` がインデックス（1行/メモリ）。

---

*この Playbook は使いながら改善する前提。気付いたカスタマイズ・落とし穴は本ドキュメントに追記していく。*
