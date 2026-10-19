-- supabase-vercel-audit / Layer A（Supabase Postgres）
-- すべて読み取りのみ。psql "$DATABASE_URL" -f queries.sql か、Supabase MCP の execute_sql で 1 本ずつ実行する。
-- 'public' 以外のスキーマを API に公開している場合（A8 の結果）は、各クエリの 'public' をそのスキーマ名でも実行する。
-- 権限の判定は has_*_privilege() を使う（PUBLIC 宛 GRANT・ロール継承・information_schema の可視性制限を避けるため）。

-- A8: PostgREST が API に公開しているスキーマ（既定: public, graphql_public, storage）
select rolname, cfg as config
from pg_roles r, unnest(r.rolconfig) cfg
where r.rolname = 'authenticator'
order by cfg;

-- A1: RLS が無効のテーブル（CRITICAL。anon / authenticated に権限が無ければ A4a と突合して下げる）
select n.nspname as schema, c.relname as "table", c.relforcerowsecurity as rls_forced,
       has_table_privilege('anon', c.oid, 'SELECT') as anon_select,
       has_table_privilege('authenticated', c.oid, 'SELECT') as authenticated_select
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind in ('r', 'p')
  and n.nspname = 'public'
  and not c.relrowsecurity
order by 2;

-- A2: RLS は有効だがポリシーが 1 つも無いテーブル（HIGH: 意図を確認）
select n.nspname as schema, c.relname as "table"
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind in ('r', 'p')
  and n.nspname = 'public'
  and c.relrowsecurity
  and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
order by 2;

-- A3a: 条件が true のポリシー（CRITICAL〜HIGH。SELECT の公開マスタ以外は要修正）
select schemaname, tablename, policyname, cmd, roles, permissive, qual, with_check
from pg_policies
where schemaname = 'public'
  and (
    regexp_replace(coalesce(qual, ''), '[\s()]', '', 'g') = 'true'
    or regexp_replace(coalesce(with_check, ''), '[\s()]', '', 'g') = 'true'
  )
order by tablename, policyname;

-- A3b: 条件に auth.uid() / auth.jwt() / auth.role() を使っていないポリシー（MEDIUM: 行所有者条件になっているか目視）
select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and coalesce(qual, '') !~ 'auth\.(uid|jwt|role)\(\)'
  and coalesce(with_check, '') !~ 'auth\.(uid|jwt|role)\(\)'
order by tablename, policyname;

-- A3c: 「ログインしていれば誰でも」型と user_metadata 参照型（CRITICAL〜HIGH）
--      auth.uid() is not null / auth.role() = 'authenticated' は signup 開放なら公開と同じ。
--      user_metadata は利用者が auth.updateUser() で自由に書けるので、role 判定に使うと自己昇格できる
--      （advisor: rls_references_user_metadata）。app_metadata か独自テーブルで判定する
select schemaname, tablename, policyname, cmd, roles, permissive, qual, with_check
from pg_policies
where schemaname = 'public'
  and (coalesce(qual, '') || ' ' || coalesce(with_check, ''))
      ~* 'user_metadata|raw_user_meta_data|auth\.(uid|jwt)\(\) is not null|auth\.role\(\) *= *''authenticated'''
order by tablename, policyname;

-- A4a: anon / authenticated の実効テーブル権限（PUBLIC 宛 GRANT と継承を含む）。
--      anon に INSERT / UPDATE / DELETE があれば要確認。どの列も true でないテーブルは Data API から直接は触れない
select n.nspname as schema, c.relname as "table", c.relkind,
       has_table_privilege('anon', c.oid, 'SELECT') as anon_select,
       has_table_privilege('anon', c.oid, 'INSERT') as anon_insert,
       has_table_privilege('anon', c.oid, 'UPDATE') as anon_update,
       has_table_privilege('anon', c.oid, 'DELETE') as anon_delete,
       has_table_privilege('authenticated', c.oid, 'SELECT') as auth_select,
       has_table_privilege('authenticated', c.oid, 'INSERT') as auth_insert,
       has_table_privilege('authenticated', c.oid, 'UPDATE') as auth_update,
       has_table_privilege('authenticated', c.oid, 'DELETE') as auth_delete
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p', 'v', 'm', 'f')
order by 2;

-- A4b: anon / authenticated が UPDATE できる「権限・課金っぽい」列（HIGH: 自己権限昇格の候補）
--      自分の行を更新できるポリシーがある場合、列単位で revoke update するか、trigger で固定する
select n.nspname as schema, c.relname as "table", a.attname as "column",
       has_column_privilege('anon', c.oid, a.attnum, 'UPDATE') as anon_update,
       has_column_privilege('authenticated', c.oid, a.attnum, 'UPDATE') as authenticated_update
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
  and a.attname ~* '(role|admin|plan|tier|credit|balance|point|status|verified|approved|permission|owner|price|amount|quota|limit)'
  and (has_column_privilege('anon', c.oid, a.attnum, 'UPDATE')
       or has_column_privilege('authenticated', c.oid, a.attnum, 'UPDATE'))
order by 2, 3;

-- A5: SECURITY DEFINER 関数（trigger 関数を除く）と anon / authenticated の EXECUTE 可否、search_path 固定、auth.users 参照（HIGH）
select n.nspname as schema,
       p.proname as function,
       pg_get_function_identity_arguments(p.oid) as args,
       (select string_agg(cfg, ' ') from unnest(p.proconfig) cfg where cfg like 'search_path=%') as search_path,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_exec,
       p.prosrc ~* 'auth\.users|raw_user_meta_data' as touches_auth_users
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and p.prorettype <> 'trigger'::regtype
order by 2;

-- A6a: view の security_invoker 設定、RLS テーブルへの参照、anon / authenticated の SELECT 可否
--      security_invoker でなく、RLS テーブルを参照し、anon か authenticated が SELECT できるものが HIGH（RLS を迂回する）
select n.nspname as schema, c.relname as view, pg_get_userbyid(c.relowner) as owner,
       coalesce(array_to_string(c.reloptions, ',') ~* 'security_invoker=(true|on|1|yes|t|y)', false) as security_invoker,
       exists (
         select 1
         from pg_rewrite r
         join pg_depend d on d.objid = r.oid and d.classid = 'pg_rewrite'::regclass
         join pg_class t on t.oid = d.refobjid and d.refclassid = 'pg_class'::regclass
         where r.ev_class = c.oid and t.oid <> c.oid and t.relrowsecurity
       ) as refs_rls_table,
       has_table_privilege('anon', c.oid, 'SELECT') as anon_select,
       has_table_privilege('authenticated', c.oid, 'SELECT') as authenticated_select
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'v'
  and n.nspname = 'public'
order by 2;

-- A6b: materialized view（security_invoker を持てず、SELECT できれば参照元の RLS を完全に迂回する。advisor: materialized_view_in_api）
select n.nspname as schema, c.relname as matview,
       has_table_privilege('anon', c.oid, 'SELECT') as anon_select,
       has_table_privilege('authenticated', c.oid, 'SELECT') as authenticated_select
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'm'
  and n.nspname = 'public'
order by 2;

-- A7a: auth.users を参照する public の view / materialized view（CRITICAL）
select n.nspname as schema, c.relname as view, c.relkind,
       has_table_privilege('anon', c.oid, 'SELECT') as anon_select,
       has_table_privilege('authenticated', c.oid, 'SELECT') as authenticated_select
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind in ('v', 'm')
  and n.nspname = 'public'
  and pg_get_viewdef(c.oid) ~* 'auth\.users'
order by 2;

-- A7b: auth.users への実効 SELECT 権限（CRITICAL。どちらかが true なら email 等が API から読める）
select has_table_privilege('anon', 'auth.users', 'SELECT') as anon_select,
       has_table_privilege('authenticated', 'auth.users', 'SELECT') as authenticated_select;

-- A9a: storage bucket の公開設定（HIGH）
select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
order by name;

-- A9b: storage.objects のポリシー（select が true なら private bucket でも列挙できる）
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
order by policyname;

-- A10: Realtime で配信しているテーブル（MEDIUM: ポリシーが緩いと変更が垂れ流し）
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by 1, 2;

-- 参考: 新しく作るテーブルに自動で付く既定権限（Supabase 既定で anon / authenticated に付く。RLS 必須の理由）
select defaclrole::regrole as role, defaclnamespace::regnamespace as schema, defaclobjtype as objtype, defaclacl as acl
from pg_default_acl
order by 1, 2, 3;
