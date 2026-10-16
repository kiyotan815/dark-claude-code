---
description: Supabase + Vercel（+ Next.js）構成の情報漏洩リスクを横断監査し、重大度付きレポートを docs/security/ に書く。RLS・GRANT・鍵の露出・cron / preview 保護・外形からの anon 列挙など設定ミス型の事故が主対象。監査は read-only で何も変更しない。
---

# Security Audit

`$ARGUMENTS`:

```
/dcc:security-audit                       # 全レイヤー（DB 設定・鍵/コード・Vercel・GitHub）
/dcc:security-audit --config-only         # Layer A / C / D のみ。security-reviewer によるコード確認を省く
/dcc:security-audit --probe               # Layer E（外形確認）も実行。SUPABASE_URL / SUPABASE_ANON_KEY / APP_URL が必要
/dcc:security-audit --compare <path>...   # 複数リポジトリを同じチェックリストで横並びにする
```

**監査は read-only。** 本番 DB・Vercel 設定・コードを変更しない。修正は所見ごとに別途（migration / PR）行う。
外形確認は自社プロダクトに対して anon キーでのみ行う。service_role は使わない。

## 手順

1. **スコープ確認** — リポジトリ（`git remote -v`）、Supabase（MCP があれば `get_project_url`、無ければ `supabase/config.toml` の `project_id` と `.env.example`）、Vercel（`vercel.json`、`.vercel/project.json`）、Next.js のバージョン（`package.json`）。対象を 1 行で提示して進める（確認待ちはしない）
2. **dcc:supabase-vercel-audit skill** を読み込み、Layer A（DB）と Layer B（鍵 / コード grep）を並列で実行する
   - A: Supabase MCP があれば `get_advisors(type: security)` → `execute_sql` で skill の `queries.sql` を 1 本ずつ。MCP が無ければ `DATABASE_URL` で psql。それも無ければ「ダッシュボードで実行する手順」を所見に書いて次へ進む
   - B: 見つかった鍵はデコードして role を確認する。service_role がリポジトリか履歴にあれば CRITICAL とし、ローテーション手順を所見に含める
3. `--config-only` でなければ **dcc:security-reviewer agent** を、skill の Layer B 末尾にある brief（IDOR / getSession / service_role 誤用 / webhook 署名 / middleware 依存）で起動し、Route Handler・Server Action・middleware を見せる。手順 2 と同じメッセージで並列に起動する
4. **Layer C（Vercel / Next.js）** — `vercel env ls`、`vercel.json` の `crons` とハンドラの `CRON_SECRET` 検証、Next.js のバージョン（CVE-2025-29927）。Deployment Protection などダッシュボードでしか見えない項目は「人手で確認する項目」として残す
5. **Layer D（GitHub）** — `/dcc:vuln-fix --report` と同じ `gh api` で Dependabot / secret scanning / code scanning の状態を取る。`gitleaks` があれば履歴をスキャンする
6. `--probe` なら **Layer E** — skill の `probe.sh` を実行し、anon で読めるテーブルを A1〜A3 の所見と突合する
7. **レポート** — `docs/security/audit-YYYY-MM-DD.md` を skill の形式で書く。所見は証拠 → 影響 → 修正（SQL / コード）。ユーザーには CRITICAL / HIGH の要約と、人手が要る確認（ダッシュボード項目・ローテーション）を箇条書きで返す
8. **修正は別作業** — RLS / GRANT は migration、コードは小さければ直接、まとまっていれば `/dcc:codex-spec` に渡す。修正後は Layer A と E を再実行して閉じる

`--compare` は各リポジトリで手順 1〜6 を実行し、skill のチェックリスト表の列をプロダクトにした 1 本のレポートにする。3 リポジトリ以上なら Workflow（`ultracode`）での並列実行を提案する。

## 判断の目安

- 「anon で読める行がある」「service_role がクライアントにある」「RLS 無効」は、利用者データを含む限り CRITICAL。公開マスタ（都道府県一覧など）だけなら所見に理由を書いて LOW
- authenticated 向けの `using (true)` は、signup が開放されていれば anon と同じ扱い
- 修正提案は「適用後に何で確認するか」（probe の再実行、クエリ結果が空になること）まで書く
