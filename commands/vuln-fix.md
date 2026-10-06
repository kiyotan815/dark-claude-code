---
description: GitHub の脆弱性アラート（Dependabot / code scanning / secret scanning）を取得し、修正して PR を作る。Dependabot が自動修復できないものを主対象にする。
---

# Vulnerability Fix

GitHub Security タブの脆弱性を起点に、修正 PR の作成までを行う。`$ARGUMENTS`:

```
/dcc:vuln-fix                    # open アラートを全部見て、修正計画を提示
/dcc:vuln-fix critical high      # 深刻度で絞る
/dcc:vuln-fix --alert 42         # 特定のアラート1件だけ修正
/dcc:vuln-fix --report           # 修正せず一覧レポートのみ
```

**主対象は Dependabot security updates が自動修復できないもの。**
直接依存に patch 版があるだけのケースは Dependabot が勝手に PR を作るので、
このコマンドの価値は transitive 依存・パッチ未提供・破壊的変更・コードスキャン結果にある。

---

## 1. Preflight

`gh repo view --json nameWithOwner` でリポジトリを特定してから:

```bash
gh api "/repos/{owner}/{repo}/dependabot/alerts?state=open&per_page=100" --paginate
```

エラー時の対応（**ここで止まらず、有効化を案内してから続行判断を仰ぐ**）:

| 応答 | 意味 | 案内 |
|---|---|---|
| `403 Dependabot alerts are disabled` | リポジトリで未有効化 | Settings → Code security → Dependabot alerts を ON。または `gh api -X PATCH /repos/{owner}/{repo} -F security_and_analysis[...]` |
| `403 must have admin` / scope 不足 | トークン権限不足 | `gh auth refresh -h github.com -s security_events` |
| `404 no analysis found`（code scanning） | CodeQL 未実行 | 対象なしとして扱い、他ソースを続行 |

---

## 2. アラートを集める

3ソースを取得する（存在しないものはスキップ）:

```bash
# 依存の脆弱性
gh api "/repos/{owner}/{repo}/dependabot/alerts?state=open&per_page=100" --paginate --jq '.[] | {
  number, severity: .security_advisory.severity, ghsa: .security_advisory.ghsa_id,
  cve: .security_advisory.cve_id, summary: .security_advisory.summary,
  pkg: .dependency.package.name, ecosystem: .dependency.package.ecosystem,
  scope: .dependency.scope, manifest: .dependency.manifest_path,
  vulnerable: .security_vulnerability.vulnerable_version_range,
  patched: .security_vulnerability.first_patched_version.identifier }'

# コードの脆弱性（CodeQL の security-and-quality 等）
gh api "/repos/{owner}/{repo}/code-scanning/alerts?state=open&per_page=100" --paginate --jq '.[] | {
  number, rule: .rule.id, severity: .rule.security_severity_level,
  desc: .rule.description, path: .most_recent_instance.location.path,
  line: .most_recent_instance.location.start_line,
  message: .most_recent_instance.message.text }'

# 漏洩シークレット
gh api "/repos/{owner}/{repo}/secret-scanning/alerts?state=open&per_page=100" --paginate --jq '.[] | {
  number, type: .secret_type_display_name, path: .locations_url, created: .created_at }'
```

---

## 3. トリアージ

**`dependency.scope`（runtime / development）と `first_patched_version` の有無で優先度が決まる。**
runtime かつ critical/high を最優先、development のみに閉じるものは後回し。

各アラートを修復戦略で分類する:

| 戦略 | 条件 | 対応 |
|---|---|---|
| **直接バンプ** | 直接依存 & patched 版あり & semver 互換 | manifest を書き換えて lockfile 更新 |
| **transitive 解決** | 間接依存 & 親が未対応 | npm `overrides` / pnpm `overrides` / yarn `resolutions` / bundler は親を bump |
| **破壊的変更あり** | patched 版が major 跨ぎ | 影響箇所を Grep で特定し、コード修正込みで対応 |
| **パッチ未提供** | `first_patched_version` が null | 代替パッケージ・自前回避策・リスク受容の判断材料を出す |
| **コード修正** | code scanning alert | 該当箇所を読んで修正（dcc:security-reviewer agent に妥当性を確認） |
| **要ローテーション** | secret scanning alert | **自動修正しない**（後述） |

破壊的変更を含む場合は、**そのパッケージの変更 API を自コードベースのどこで使っているか**を
Grep で特定し、影響ファイルと行を出す。ここは agent を並列起動してよい。

### レポート形式

```
VULNERABILITY REPORT — open: N件 (critical X / high Y / moderate Z / low W)

要対応 (runtime)
  #42  critical  CVE-2025-xxxxx  lodash 4.17.20 → 4.17.21   直接バンプ
  #37  high      GHSA-xxxx       ws (transitive)             overrides で解決
                 経路: express > body-parser > ws
  #31  high      CVE-2025-yyyyy  next 14 → 15                破壊的変更
                 影響: src/app/layout.tsx ほか4ファイル

コード (code scanning)
  #8   high  js/sql-injection  src/db/query.ts:47
             文字列連結でクエリ生成 → パラメータ化が必要

シークレット (要人手)
  #3   AWS Access Key ID  ← ローテーション必須。コマンドでは修正しない

後回し可 (development のみ)
  #45  moderate  esbuild 0.19 → 0.21   dev 依存のみ、本番影響なし
```

---

## 4. 修正

**戦略ごとにブランチを分ける。** 1本の巨大な PR にしない。

推奨の切り方:
- `fix/vuln-critical-<日付>` — critical/high の直接バンプ + transitive をまとめて1本
- 破壊的変更は**アラート1件につき1本**（レビュー単位を小さく保つ）
- code scanning の修正は**ルール単位**で1本

修正規模でルーティングする（グローバル CLAUDE.md の基準）:
- 数ファイル以内 → Claude が直接修正
- 複数ファイルにまたがる / 並列化できる → **codex-delegate skill** で委譲し、
  **codex-auditor agent** で監査してから戻る
- 修正後にビルドが壊れたら、エラーを 1 件ずつ直して都度検証する（rules/performance.md）

### secret scanning は例外

**コマンドでコミットして解決しない。** シークレットの漏洩は
「リポジトリから消す」ことでは解決せず、鍵のローテーションが本体。
以下を報告して人手に委ねる:

1. 該当シークレットの失効・再発行（プロバイダ側の作業）
2. 環境変数への移行と `.gitignore` の確認
3. 履歴からの除去が必要かの判断（force-push の影響があるため独断で行わない）

---

## 5. 検証

修正ブランチごとに:

1. 依存を再インストールして lockfile が整合しているか確認
2. テスト実行（回帰がないこと）
3. build / 型チェック / lint を 1 コマンドで連結して実行（rules/git-workflow.md）
4. 可能なら再スキャン: `gh api /repos/{owner}/{repo}/dependabot/alerts` で
   対象アラートが消えるか（反映に時間差があるため、消えなくても失敗としない）

**テストが通らない修正は PR にしない。** 状況を報告して判断を仰ぐ。

---

## 6. PR を作る

**pr-helper skill** に従って作成する（複数行 body の扱い）。

PR body に必ず含める:

```markdown
## 対応した脆弱性
| Alert | 深刻度 | CVE/GHSA | パッケージ | 対応 |
|---|---|---|---|---|
| #42 | critical | CVE-2025-xxxxx | lodash 4.17.20 → 4.17.21 | 直接バンプ |

## 変更内容
（transitive の場合は overrides を入れた理由と経路を明記）

## 検証
- [ ] テスト: X/Y passed
- [ ] build / 型チェック
- [ ] 破壊的変更の影響箇所を確認（該当ファイル列挙）

## 残存リスク
（パッチ未提供でリスク受容したもの、後回しにした dev 依存など）
```

作成後、PR URL とアラート番号の対応を報告する。

---

## 全体のルール

- **PR 作成・push はユーザー確認後**。アラート収集・調査・修正計画までは自律的に進めてよい
- 深刻度を自己判断で下げない。GitHub の severity をそのまま使い、
  `scope: development` などの緩和要因は「後回し可」の理由として明示する
- パッチ未提供のものを「対応不能」で終わらせず、代替案（別パッケージ・自前回避・
  設定での無効化）を最低1つ提示する
- アラートの dismiss（却下）は提案のみ。**コマンドから dismiss API を叩かない**

---

## 定期実行する場合

`--report` は人手を介さないので routine 化できる。`/schedule` で
「毎週月曜 9:00 に `/dcc:vuln-fix --report` を実行し、critical / high があれば
Issue を立てる」のようなクラウド routine を作る。修正と PR 作成は人が確認する
前提なので routine には入れない。
