#!/usr/bin/env bash
#
# supabase-vercel-audit / Layer E: 外形確認（read-only）。
# 自社プロダクトに対して anon / publishable キーでのみ使う。GET / HEAD しか送らない。
#
# 環境変数:
#   SUPABASE_URL       https://<ref>.supabase.co
#   SUPABASE_ANON_KEY  anon（legacy JWT）または sb_publishable_... キー
#   APP_URL            任意。アプリの本番 URL（応答ヘッダの確認）
#
# 使い方:
#   SUPABASE_URL=... SUPABASE_ANON_KEY=... APP_URL=... bash probe.sh
#
# 読み方:
#   "anon が読める"  … Content-Range が 0-0/N（N は総数、* は数えられなかった）。公開マスタ以外は CRITICAL
#   rows 0           … RLS で遮断されているか、空のテーブル。ポリシー（queries.sql A3）と突合する
#   rows -           … 権限なし / 非公開（401 / 403 / 404 / 406）
#   "要再確認"       … 5xx 等。count=exact が statement_timeout（anon は既定 3 秒）に掛かった可能性。OK ではない
set -euo pipefail

: "${SUPABASE_URL:?SUPABASE_URL を設定してください}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY を設定してください}"
SUPABASE_URL="${SUPABASE_URL%/}"

for cmd in curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "probe: $cmd が必要です" >&2; exit 1; }
done

say() { printf '\n== %s ==\n' "$*"; }

# 0. キーの種別を確認する。service_role / secret キーでは実行しない
case "$SUPABASE_ANON_KEY" in
  sb_secret_*)
    echo "probe: secret キーでは実行しません" >&2; exit 2 ;;
  sb_publishable_*)
    echo "key: publishable" ;;
  eyJ*)
    role="$(printf '%s' "$SUPABASE_ANON_KEY" | cut -d. -f2 | python3 -c '
import sys, base64, json
s = sys.stdin.read().strip()
s += "=" * (-len(s) % 4)
try:
    print(json.loads(base64.urlsafe_b64decode(s)).get("role", "?"))
except Exception:
    print("?")')"
    echo "key role: $role"
    [ "$role" = "anon" ] || { echo "probe: anon 以外のキー (${role}) では実行しません" >&2; exit 2; } ;;
  *)
    echo "probe: キー形式を判定できません。anon / publishable キーを渡してください" >&2; exit 2 ;;
esac

H=(-H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY")

# HEAD /rest/v1/<object>?select=*&limit=1 を送り、CR を除いたヘッダを返す。$2 は追加ヘッダ
probe_head() {
  curl -sS -I "${H[@]}" -H "$2" "$SUPABASE_URL/rest/v1/$1?select=*&limit=1" 2>/dev/null | tr -d '\r' || true
}
first_status() { printf '%s\n' "$1" | awk 'NR==1 {print $2}'; }
content_range() { printf '%s\n' "$1" | awk 'tolower($0) ~ /^content-range:/ {print $2}'; }

# 1. OpenAPI: anon から見える公開テーブル / view / RPC（PostgREST 既定の follow-privileges なので、
#    ここに出る = anon に権限がある。PUBLIC 宛 GRANT もここで露見する）
say "公開オブジェクト (GET /rest/v1/)"
spec="$(curl -sS "${H[@]}" "$SUPABASE_URL/rest/v1/" || true)"
paths="$(printf '%s' "$spec" | python3 -c '
import sys, json
from urllib.parse import quote
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(d, dict):
    sys.exit(0)
for p in sorted(d.get("paths", {})):
    if p != "/":
        print(quote(p.lstrip("/"), safe="/"))')"
if [ -z "$paths" ]; then
  echo "OpenAPI を取得できません（Data API が無効か、キーが違う）。応答の先頭:"
  printf '%s\n' "${spec:0:300}"
else
  printf '%s\n' "$paths"
fi

# 2. 各テーブルを HEAD + Prefer: count=exact で叩き、anon が読める行数を Content-Range から取る
if [ -n "$paths" ]; then
  say "anon で読める行数 (HEAD + Prefer: count=exact)"
  printf '%-40s %-7s %-8s %s\n' "object" "status" "rows" ""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in rpc/*) continue ;; esac
    hdr="$(probe_head "$p" 'Prefer: count=exact')"
    status="$(first_status "$hdr")"
    note=""
    case "$status" in
      200|206|401|403|404|406) ;;
      *)
        # count=exact が statement_timeout に掛かると 5xx になる。count 無しで 1 回だけ再試行
        note=" (count=exact は ${status:-応答なし}。count 無しで再試行)"
        hdr="$(probe_head "$p" 'Accept: application/json')"
        status="$(first_status "$hdr")" ;;
    esac
    cr="$(content_range "$hdr")"   # 0-0/1842, */0, 0-0/*
    rows="?"; flag=""
    case "$status" in
      200|206)
        case "$cr" in
          [0-9]*-[0-9]*/*) rows="${cr#*/}"; flag="  <-- anon が読める" ;;
          '*/0')           rows="0" ;;
          *)               flag="  <-- 要再確認 (Content-Range: ${cr:-無し})" ;;
        esac ;;
      401|403|404|406) rows="-" ;;
      *) flag="  <-- 要再確認 (status ${status:-?})" ;;
    esac
    printf '%-40s %-7s %-8s %s%s\n' "$p" "${status:-?}" "$rows" "$flag" "$note"
  done <<<"$paths"
fi

# 3. Auth 設定（公開エンドポイント）
say "Auth 設定 (GET /auth/v1/settings)"
curl -sS "${H[@]}" "$SUPABASE_URL/auth/v1/settings" 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("取得できません"); sys.exit(0)
if not isinstance(d, dict):
    print("取得できません"); sys.exit(0)
signup_open = not d.get("disable_signup", False)
print("disable_signup:", d.get("disable_signup"), "  <-- 誰でも authenticated になれる" if signup_open else "")
print("mailer_autoconfirm:", d.get("mailer_autoconfirm"))
print("phone_autoconfirm:", d.get("phone_autoconfirm"))
ext = d.get("external", {}) or {}
print("anonymous sign-ins:", ext.get("anonymous_users"))
print("external providers:", ", ".join(k for k, v in ext.items() if v and k != "anonymous_users") or "(none)")' || true

# 4. アプリの応答ヘッダ（リダイレクトを追い、最終応答のブロックだけを見る）
if [ -n "${APP_URL:-}" ]; then
  say "アプリの応答ヘッダ ($APP_URL)"
  hdr="$(curl -sS -I -L "$APP_URL" 2>/dev/null | tr -d '\r' | awk -v RS='' 'END {print}' || true)"
  printf '%s\n' "$hdr" | awk 'NR==1'
  for h in strict-transport-security content-security-policy x-content-type-options x-frame-options referrer-policy permissions-policy; do
    # grep が 0 件でも pipefail で落ちないように || true
    v="$(printf '%s\n' "$hdr" | grep -i "^$h:" | tail -1 | cut -d: -f2- | sed 's/^ *//' | cut -c1-100 || true)"
    printf '%-28s %s\n' "$h" "${v:-(なし)}"
  done
fi

say "完了。所見は docs/security/audit-YYYY-MM-DD.md に重大度付きで記録する（鍵本体は書かない）"
