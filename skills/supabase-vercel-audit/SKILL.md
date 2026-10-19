---
name: supabase-vercel-audit
description: Supabase + Vercel（+ Next.js）構成の情報漏洩リスクを設定レイヤーから監査するワークフロー。RLS 無効・過剰 GRANT・service_role 露出・公開 bucket・未保護の cron / preview・外形からの anon 列挙など「設定ミスで丸見え」型の事故を対象にする。/dcc:security-audit から呼ばれるほか、Supabase / Vercel を使うプロジェクトでセキュリティ確認・漏洩対策・RLS の見直しを頼まれたときに使う。コードの脆弱性パターン（injection / XSS 等）は security-review skill と security-reviewer agent が担当。
---

# Supabase + Vercel Audit

国内で続いた漏洩事故の多くは、コードのバグではなく **設定ミス** が原因だった。RLS 無効のテーブルが anon キーで読める、service_role キーがクライアントに出ている、bucket が公開、cron エンドポイントが認証なし、といった類型である。このスキルはその類型を 5 レイヤーに分け、どのプロダクトにも同じ物差しを当てて重大度付きのレポートにする。

**前提**: 監査は read-only。本番 DB・Vercel 設定・コードを変更しない。外形確認は自社プロダクトに対して anon（publishable）キーでのみ行い、service_role / secret キーでは叩かない。

同梱ファイル:

- [queries.sql](queries.sql) — Layer A の SQL（読み取りのみ）
- [probe.sh](probe.sh) — Layer E の外形確認（GET / HEAD のみ）

## 進め方

1. スコープ確認: 対象リポジトリ、Supabase プロジェクト（MCP が繋がっていれば `get_project_url`）、本番 / preview の URL
2. Layer A → E を順に。A（DB）と B（コード grep）は独立なので並列にできる。B の認可レビュー部分は security-reviewer agent に投げる
3. 所見は「証拠（クエリ結果・ファイル:行・HTTP 応答）→ 影響 → 修正」の形で記録する
4. レポートを `docs/security/audit-YYYY-MM-DD.md` に書く（形式は末尾）
5. 修正は別作業。RLS / GRANT は migration、コードは通常のフロー（小さければ直接、まとまっていれば codex-spec）

## Layer A: データベース（Supabase Postgres）

実行手段（どれか 1 つ）:

- Supabase MCP: まず `get_advisors(type: "security")`、次に `execute_sql` で queries.sql を 1 本ずつ
- psql: `psql "$DATABASE_URL" -f queries.sql`（Direct connection か Session pooler）
- ダッシュボード: Advisors → Security を見てから、SQL Editor に queries.sql を貼る

Advisor の主な lint 名: `rls_disabled_in_public` / `policy_exists_rls_disabled` / `rls_enabled_no_policy` / `rls_references_user_metadata` / `security_definer_view` / `materialized_view_in_api` / `foreign_table_in_api` / `insecure_queue_exposed_in_api` / `function_search_path_mutable` / `auth_users_exposed` / `auth_allow_anonymous_sign_ins` / `auth_otp_long_expiry` / `auth_leaked_password_protection` / `extension_in_public`。

| # | 確認 | 重大度 | 理由 |
|---|---|---|---|
| A1 | 公開スキーマの全テーブルで RLS 有効 | CRITICAL | 無効なら anon キーで全行の読み書きができる |
| A2 | RLS 有効だがポリシー 0 件 | HIGH（意図確認） | 全拒否で機能が壊れているか、service_role 専用のつもり |
| A3 | `USING (true)` / `WITH CHECK (true)` が anon / authenticated に向いている | CRITICAL〜HIGH | 実質 RLS 無し。公開マスタの SELECT は可、INSERT / UPDATE / DELETE は不可 |
| A4 | anon / authenticated が UPDATE できる列に `role` `plan` `is_admin` `balance` 等 | HIGH | 自分の行を更新できるポリシー + 列制限なしで自己権限昇格（p-mill の PMILL-158 型） |
| A5 | SECURITY DEFINER 関数に anon / authenticated の EXECUTE | HIGH | RLS を迂回して実行される。`search_path` 未固定なら乗っ取り可能 |
| A6 | `security_invoker` でない view が RLS テーブルを参照し、anon / authenticated が SELECT できる。materialized view は常に該当 | HIGH | view はオーナー権限で動き RLS を迂回する。matview はスナップショットなので完全に迂回 |
| A7 | `auth.users` を参照する public view、または `auth.users` への直接 GRANT | CRITICAL | email 等が anon から読める |
| A8 | PostgREST の公開スキーマ（`pgrst.db_schemas`）に意図しないスキーマ | HIGH | public 以外も API 経由で見える |
| A9 | `storage.buckets.public = true`、`storage.objects` のポリシー | HIGH | 公開 bucket は URL を知れば誰でも。private でも select ポリシーが `true` なら列挙可 |
| A10 | Realtime publication に載っているテーブル | MEDIUM | RLS は効くが、ポリシーが緩いと変更が垂れ流し |
| A11 | Edge Functions が関数内で `auth.getUser()` を呼んで認証しているか（`verify_jwt` の値に関わらず）。service_role を使う関数は呼び出し元を限定しているか | MEDIUM〜HIGH | `verify_jwt = true` でも anon キーは通る。新 API キー（`sb_publishable_`）は JWT でないので `verify_jwt = false` + 関数内認証が Supabase の推奨。認証なしで service_role を使っていれば CRITICAL |
| A12 | Auth 設定: signup 開放 + autoconfirm、OTP 有効期限、漏洩パスワード保護、redirect URL 許可リスト | MEDIUM | 下記 |

**重大度は A4a の実効権限と合わせて決める。** A4a で anon / authenticated のどの権限も false のテーブルは Data API から直接は触れない（view や SECURITY DEFINER の RPC 経由は別）ので、RLS 無効（A1）や `true` ポリシー（A3）でも実害は限定的。逆に権限があって RLS 無効なら、確実に CRITICAL。A4a は `has_table_privilege()` で判定するので、`grant ... to public` のような付与も拾う。

**authenticated は信頼できる相手ではない。** `GET /auth/v1/settings` で `disable_signup: false` なら誰でも authenticated になれる。ポリシーは `(select auth.uid()) = user_id` のような行所有者条件まで落とすこと。`to authenticated using (true)` は signup 開放の環境では公開と同じ。

## Layer B: キーとコード

`git grep -n` で探す（`find` は sandbox で失敗することがある）:

```bash
# service_role / secret キーがクライアント側や公開変数に無いか
git grep -nE 'SERVICE_ROLE|sb_secret_|service_role' -- ':!*.md' ':!supabase/migrations'
git grep -nE 'NEXT_PUBLIC_[A-Z_]*(SECRET|SERVICE|PRIVATE|TOKEN)'
# JWT 直書き（legacy の anon / service_role キーは eyJ で始まる）
git grep -nE 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.' -- ':!package-lock.json' ':!*.lock'
# server 用キーを使うファイルが client 境界に無いか
git grep -ln 'SUPABASE_SERVICE_ROLE_KEY' -- app src components pages 2>/dev/null
```

- 見つかった JWT は 2 つ目のセグメントを base64 デコードして `role` を確認する。`service_role` がリポジトリか履歴にあれば **CRITICAL、即ローテーション**。legacy の service_role JWT は単独で無効化できず JWT secret のローテーション（anon も無効化、全クライアント再デプロイ）になる。新形式の `sb_secret_` は個別にローテーションできるので、これを機に移行する
- service_role を使うコードは server-only（`import 'server-only'`、Route Handler、Server Action、Edge Function）に閉じているか。同じファイルに `'use client'` があれば CRITICAL
- `.env*`、`.vercel/`、`supabase/.temp/` が git 管理外か: `git ls-files | grep -E '^\.env|^\.vercel/|supabase/\.temp'`（`.env.example` は可）
- 履歴: `gitleaks git -v .`（`brew install gitleaks`）。過去 commit の鍵は今消えていても漏洩扱いでローテーションする

認可（IDOR）はコードの問題なので **security-reviewer agent** に次の brief で委ねる:

> Route Handler（`app/api/**/route.ts`）、Server Action（`'use server'`）、webhook、`middleware.ts` を対象に、(1) request body / params の userId を信じて `auth.uid()` と突合していない箇所、(2) `supabase.auth.getSession()` だけで検証している箇所（server では `getUser()`）、(3) service_role クライアントにユーザー入力をそのまま条件として渡している箇所、(4) webhook の署名検証が無い箇所、(5) middleware の matcher から漏れている保護対象ルート、を file:line で列挙する。

## Layer C: Vercel / Next.js

| # | 確認 | 重大度 |
|---|---|---|
| C1 | `vercel env ls`: secret 系が `NEXT_PUBLIC_` でない、Sensitive 指定、環境スコープ（preview に本番 DB の鍵が無いか） | HIGH |
| C2 | Deployment Protection: preview が Vercel Authentication か Password で保護されている（preview が本番データを指すなら必須） | HIGH |
| C3 | `vercel.json` の `crons`: 各ハンドラが `Authorization: Bearer ${CRON_SECRET}` を検証している | HIGH |
| C4 | Next.js のバージョン: middleware 迂回 CVE-2025-29927（修正版 15.2.3 / 14.2.25 / 13.5.9 / 12.3.5）。Vercel ホスティングはエッジで該当ヘッダを遮断しているので「要更新」だが即時に悪用可能ではない | HIGH（セルフホストなら CRITICAL） |
| C5 | 認可を middleware だけに頼っていない。Route Handler / Server Component 側でも `getUser()` | HIGH |
| C6 | Server Action は全部公開エンドポイント。入口で認証と入力検証（zod） | HIGH |
| C7 | webhook（Stripe / LINE / Supabase Database Webhook 等）の署名検証 | HIGH |
| C8 | `images.remotePatterns` のワイルドカード（`/_next/image` が open proxy になる） | MEDIUM |
| C9 | セキュリティヘッダ（HSTS / CSP / X-Content-Type-Options / frame-ancestors） | LOW〜MEDIUM |
| C10 | Vercel Firewall / rate limit: 認証・送信系エンドポイントに制限 | MEDIUM |
| C11 | ログに PII / トークンを出していない（Runtime Logs はチーム全員が見る） | MEDIUM |

確認手段: `vercel env ls`、`vercel project ls`。Deployment Protection はダッシュボードの Settings → Deployment Protection（API なら `GET https://api.vercel.com/v9/projects/<id>` の `ssoProtection` / `passwordProtection`）。CLI で取れない項目は「ユーザーが確認する項目」として所見に残す。

## Layer D: リポジトリ / GitHub

- Dependabot alerts / secret scanning（push protection 含む）/ code scanning が ON か。`/dcc:vuln-fix --report` の結果を転記する
- `supabase/migrations` で `create table` しているのに `enable row level security` が無いファイル。live DB の A1 が正で、別ファイルで有効化していれば偽陽性なので所見にする前に A1 と突合する。migration に無ければ環境を作り直したとき再発する:

  ```bash
  grep -l -i 'create table' supabase/migrations/*.sql | xargs grep -L -i 'row level security'
  ```

- seed / fixture に本物の個人情報が入っていないか

## Layer E: 外形確認（read-only、自社プロダクトのみ）

probe.sh を anon / publishable キーで実行する。やること: `GET /rest/v1/` の OpenAPI で公開オブジェクト一覧 → 各テーブルに HEAD + `Prefer: count=exact` で anon が読める行数 → `GET /auth/v1/settings` → アプリ URL の応答ヘッダ。POST は送らない。

```bash
SUPABASE_URL=https://<ref>.supabase.co SUPABASE_ANON_KEY=<anon or sb_publishable_...> APP_URL=https://example.com \
  bash <このスキルのディレクトリ>/probe.sh
```

- 「anon が読める」が付いたテーブル（Content-Range が `0-0/N`）は公開マスタ以外 CRITICAL。A1〜A3 の所見と突合する
- rows `0` は RLS で遮断か空テーブル。rows `-` は権限なし。「要再確認」（5xx 等）は count=exact が `statement_timeout`（anon は既定 3 秒）に掛かった可能性があり、**大きなテーブルほど出やすいので OK 扱いにしない**。script は count 無しで 1 回再試行する
- OpenAPI に出る = anon に権限がある（PostgREST は既定で権限のあるオブジェクトだけ返す）。`grant ... to public` のような付与もここで露見する
- `disable_signup: false` なら authenticated 向けポリシーも同じ目で見る。anonymous sign-ins が有効なら anon と authenticated の壁は無いも同然
- script は渡されたキーの role を確認し、anon 以外なら実行しない。オブジェクト名は URL エンコードして送る
- 手動で足すなら: storage の列挙 `POST /storage/v1/object/list/<bucket>`（body `{"prefix":""}`）、GraphQL introspection `POST /graphql/v1`。どちらも読み取りだが POST なので script には含めていない

## レポート形式

`docs/security/audit-YYYY-MM-DD.md`:

```markdown
# Security Audit — <product>（YYYY-MM-DD）

対象: repo <url> @ <sha> / Supabase <project ref> / Vercel <project> / 本番 <url>
方法: supabase-vercel-audit Layer A–E、security-reviewer によるコード確認、probe.sh

## サマリ
CRITICAL n / HIGH n / MEDIUM n / LOW n。総合リスク: HIGH

## 所見
### [CRITICAL] A1: public.orders の RLS が無効
証拠: queries.sql A1 の結果 / probe: HEAD /rest/v1/orders → Content-Range 0-0/1842
影響: anon キーで全注文（氏名・住所）が読める
修正: alter table public.orders enable row level security; + 所有者ポリシー。適用後に probe を再実行

## チェックリスト
| 項目 | 状態 | 備考 |
|---|---|---|
| A1 RLS 全テーブル | NG 2 件 | orders, invoices |
| C3 cron 認証 | OK | |

## 人手で確認する項目
- Vercel Deployment Protection（ダッシュボード）
- Supabase Auth → 漏洩パスワード保護

## 次回
修正 PR の後に Layer A / E を再実行。四半期ごとに全レイヤー
```

複数プロダクトを同じ物差しで比べるときは、チェックリスト表の列をプロダクトにして横並びにする。

**レポートに鍵本体や JWT 文字列を書かない**（role と file:line だけ）。レポートには project ref と anon で読めるテーブル名が並ぶので、public リポジトリでは `docs/security/` を commit せず別の場所に保管する。

## Related

- security-review skill（コードの脆弱性パターン）、security-reviewer agent（OWASP コードレビュー）
- postgres-patterns skill（RLS ポリシーの書き方と性能）
- /dcc:vuln-fix（GitHub アラートからの修正 PR）
