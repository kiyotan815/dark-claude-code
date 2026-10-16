-- supabase-vercel-audit / Layer A（Supabase Postgres）
-- すべて読み取りのみ。psql "$DATABASE_URL" -f queries.sql か、Supabase MCP の execute_sql で 1 本ずつ実行する。
-- 'public' 以外のスキーマを API に公開している場合（A8 の結果）は、各クエリの 'public' をそのスキーマ名でも実行する。

-- A8: PostgREST が API に公開しているスキーマ（既定: public, graphql_public, storage）
select rolname, cfg as config
from pg_roles r, unnest(r.rolconfig) cfg
where r.rolname = 'authenticator'
order by cfg;

-- A1: RLS が無効のテーブル（CRITICAL）
select n.nspname as schema, c.relname as "table", c.relforcerowsecurity as rls_forced
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

-- A4a: anon / authenticated のテーブル権限一覧（anon に INSERT / UPDATE / DELETE があれば要確認）
select grantee, table_name, string_agg(privilege_type, ',' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated')
group by 1, 2
order by 1, 2;

-- A4b: anon / authenticated が UPDATE できる「権限・課金っぽい」列（HIGH: 自己権限昇格の候補）
--      自分の行を更新できるポリシーがある場合、列単位で revoke update するか、trigger で固定する
select cp.table_name, cp.column_name, cp.grantee
from information_schema.column_privileges cp
where cp.table_schema = 'public'
  and cp.privilege_type = 'UPDATE'
  and cp.grantee in ('anon', 'authenticated')
  and cp.column_name ~* '(role|admin|plan|tier|credit|balance|point|status|verified|approved|permission|owner|price|amount|quota|limit)'
order by 1, 2, 3;

-- A5: SECURITY DEFINER 関数と anon / authenticated の EXECUTE 可否、search_path 固定の有無（HIGH）
select n.nspname as schema,
       p.proname as function,
       pg_get_function_identity_arguments(p.oid) as args,
       (select string_agg(cfg, ' ') from unnest(p.proconfig) cfg where cfg like 'search_path=%') as search_path,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_exec
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
order by 2;

-- A6: security_invoker でない view（HIGH: 参照先テーブルの RLS を迂回する）
select n.nspname as schema, c.relname as view, pg_get_userbyid(c.relowner) as owner, c.reloptions
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'v'
  and n.nspname = 'public'
  and not coalesce(array_to_string(c.reloptions, ',') ~ 'security_invoker=(true|on)', false)
order by 2;

-- A7a: auth.users を参照する public の view（CRITICAL）
select n.nspname as schema, c.relname as view
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'v'
  and n.nspname = 'public'
  and pg_get_viewdef(c.oid) ~* 'auth\.users'
order by 2;

-- A7b: auth.users への直接 GRANT（CRITICAL）
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'auth'
  and table_name = 'users'
  and grantee in ('anon', 'authenticated');

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
