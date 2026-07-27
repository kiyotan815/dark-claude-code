---
description: Dependabot PR をトリアージし、破壊的変更の影響を自コードベースに照らして調査する。修正は規模でルーティング、設定見直しまで面倒を見る。
---

# Dependabot

Dependabot PR の処理。`$ARGUMENTS` でサブコマンドを指定（既定は `triage`）。

```
/dependabot              # 溜まった PR をトリアージ
/dependabot fix 142      # PR #142 の破壊的変更を通すためのコード修正
/dependabot config       # dependabot.yml を見直して PR が溜まらないようにする
```

**このコマンドの守備範囲**: 破壊的変更の影響調査と、それを通すための修正。
patch のグルーピングや自動マージは GitHub 側の設定でやるべきことなので、
`config` で設定に落とす（Claude が毎回代行しない）。

---

## triage（既定）

### 1. PR を集める

```bash
gh pr list --author "app/dependabot" --state open --json number,title,createdAt,labels,headRefName --limit 100
```

0件なら「溜まっていない」と報告して終了。

### 2. 各 PR を並列調査

PR ごとに Agent（Explore または general-purpose）を**並列起動**する。
1つの agent が1つの PR を担当し、以下を返す:

- **更新内容**: パッケージ名 / 現行 → 新 / semver 種別（patch / minor / major）
- **セキュリティ**: 脆弱性修正か（PR body の advisory、`security` ラベル）
- **破壊的変更**: PR body の release notes / changelog に breaking change の記載があるか
- **自コードベースへの影響**: そのパッケージを import/require している箇所を Grep し、
  変更された API を実際に使っているファイルと行を特定する（**ここがこのコマンドの本体**）
- **CI 状態**: `gh pr checks <番号>`

調査は読み取りのみ。この段階でコードを変更しない。

### 3. 分類して提示

| 区分 | 条件 | 提案アクション |
|---|---|---|
| **即マージ可** | patch/minor かつ CI green かつ影響箇所に API 変更なし | まとめてマージを提案 |
| **要確認** | minor だが影響箇所あり、または CI 未完了・失敗 | 影響箇所を列挙して判断を仰ぐ |
| **破壊的変更** | major、または changelog に breaking の記載 | 影響ファイルと必要な修正の概要を提示 |
| **保留推奨** | 依存が他の未マージ PR と競合、EOL 間近など | 理由を添えて後回しを提案 |

出力形式:

```
DEPENDABOT TRIAGE — open PR: N件

即マージ可 (X件)
  #12  eslint  9.39.2 → 9.40.0   patch  CI green  影響なし
  ...

要確認 (Y件)
  #18  zod  3.22 → 3.23   minor  CI green
       影響: src/api/schema.ts:14,31 で .strict() を使用（挙動変更の可能性）

破壊的変更 (Z件)
  #21  react-router  6 → 7   major  CI fail
       影響: src/routes/*.tsx 6ファイル、Route 定義の書き方が変更
       → /dependabot fix 21
```

### 4. マージ

**マージは必ずユーザーの確認を得てから行う。** 勝手にマージしない。
承認された分のみ `gh pr merge <番号> --squash`（またはプロジェクトの慣習に従う）。

---

## fix `<PR番号>`

破壊的変更を通すためのコード修正。**規模でルーティングする**（グローバル CLAUDE.md の基準に従う）:

1. PR をローカルに取り込む: `gh pr checkout <番号>`
2. 影響範囲を確定する（triage の調査結果があればそれを使う）
3. 修正規模で振り分け:
   - **数ファイル以内** → Claude が直接修正。ビルドが壊れていれば **build-error-resolver agent**
   - **複数ファイルにまたがる / 並列化できる** → **codex-delegate skill** で委譲し、
     **codex-auditor agent** で監査してから戻る
4. テストを実行して回帰がないことを確認する
5. 修正内容を PR にプッシュ、または報告して判断を仰ぐ

注意:
- Dependabot は force-push で PR を作り直すため、ローカル修正を積む場合は
  PR ブランチへの push 権限とコンフリクトに注意する。競合したら
  `@dependabot recreate` ではなく、自前ブランチに切り替えることを提案する
- テストが落ちたまま「とりあえず通す」修正はしない

---

## config

そもそも PR が溜まらないように `.github/dependabot.yml` を見直す。

1. リポジトリの構成を調べ、対象エコシステムを検出する
   （`package.json` → npm、`Gemfile` → bundler、`composer.json` → composer、
   `.github/workflows/` → github-actions、`Dockerfile` → docker、`.devcontainer/` → devcontainers）
2. 既存の `dependabot.yml` があれば読み、無ければ新規提案
3. 以下の観点で構成を提案する:
   - **grouping**: patch/minor をまとめて PR 数を減らす（`groups:`）
   - **頻度**: 日次は多すぎることが多い。`weekly` を既定に
   - **open-pull-requests-limit**: 溜まりすぎ防止
   - **ignore**: major を意図的に見送る依存があれば明示
   - **auto-merge**: patch の自動マージは Dependabot 設定ではなく
     GitHub の auto-merge + CI 必須化で行う旨を案内する（設定場所が違う）
4. 差分を提示し、ユーザーの確認を得てから書き込む

---

## 全体のルール

- **マージ・push はユーザー確認後**。調査と提案までは自律的に進めてよい
- セキュリティ勧告の深掘りが必要なら **security-reviewer agent** に繋ぐ
- 「CI が落ちているが原因不明」で止まった場合、無理に直さず状況を報告する
