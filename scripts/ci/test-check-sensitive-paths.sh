#!/usr/bin/env bash
# hooks/check-sensitive-paths.sh（opt-in の PreToolUse hook）の振る舞いテスト。
# 本番と同じく shebang（/bin/bash）で直接実行し、次を確かめる:
#   block: exit 0 + hookSpecificOutput.permissionDecision = "deny" の妥当な JSON
#   allow: 出力なし・stderr なし・exit 0
#   jq が無い / 入力が壊れている: exit 2（stderr を理由に拒否。素通しにしない）
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$ROOT/hooks/check-sensitive-paths.sh"
export CLAUDE_PROJECT_DIR="$ROOT"
failures=0

tmp="$(mktemp -d "${TMPDIR:-/tmp}/check-sensitive-paths.XXXXXX")" || exit 1
cleanup() { if [ -n "$tmp" ] && [ -d "$tmp" ]; then rm -rf -- "$tmp"; fi; }
trap cleanup EXIT
err="$tmp/stderr"

# jq を含まない PATH（cat と readlink だけ）
mkdir "$tmp/nojq"
ln -s "$(command -v cat)" "$tmp/nojq/cat"
ln -s "$(command -v readlink)" "$tmp/nojq/readlink"

# cat を含まない PATH（jq と readlink だけ）
mkdir "$tmp/nocat"
ln -s "$(command -v jq)" "$tmp/nocat/jq"
ln -s "$(command -v readlink)" "$tmp/nocat/readlink"

# 入力 JSON は jq で組み立てる（パスに引用符やバックスラッシュがあっても壊れない）
read_input() { jq -nc --arg p "$1" '{tool_name: "Read", tool_input: {file_path: $p}}'; }
bash_input() { jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'; }

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1: $2"; failures=$((failures + 1)); }

expect_deny() {
  local name="$1" input="$2" out status
  out="$(printf '%s' "$input" | "$HOOK" 2>"$err")"
  status=$?
  if [ "$status" -eq 0 ] && printf '%s' "$out" | jq -e '
      .hookSpecificOutput.hookEventName == "PreToolUse"
      and .hookSpecificOutput.permissionDecision == "deny"
      and (.hookSpecificOutput.permissionDecisionReason | length > 0)' >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "expected exit 0 + deny JSON, got exit $status: $out $(cat "$err")"
  fi
}

expect_allow() {
  local name="$1" input="$2" out status
  out="$(printf '%s' "$input" | "$HOOK" 2>"$err")"
  status=$?
  if [ "$status" -eq 0 ] && [ -z "$out" ] && [ ! -s "$err" ]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 with no output, got exit $status: $out $(cat "$err")"
  fi
}

expect_block_exit2() {
  local name="$1" input="$2" path="$3" out status
  out="$(printf '%s' "$input" | env PATH="$path" "$HOOK" 2>"$err")"
  status=$?
  if [ "$status" -eq 2 ] && [ -z "$out" ] && [ -s "$err" ]; then
    pass "$name"
  else
    fail "$name" "expected exit 2 with a reason on stderr, got exit $status: $out $(cat "$err")"
  fi
}

expect_deny  "Read の親ディレクトリ参照を拒否"            "$(read_input '../etc/passwd')"
expect_deny  "プロジェクト外の絶対パスを拒否"              "$(read_input '/etc/passwd')"
expect_deny  "パスに引用符とバックスラッシュがあっても妥当な JSON で拒否" "$(read_input '/tmp/x"y\z')"
expect_deny  "ホームディレクトリ参照を拒否"                "$(bash_input 'cat ~/.ssh/id_rsa')"
expect_deny  "origin 以外への git push を拒否"            "$(bash_input 'git push upstream main')"
expect_deny  "git remote add を拒否"                       "$(bash_input 'git remote add evil https://example.com/x.git')"
expect_deny  "外部からの git clone を拒否"                 "$(bash_input 'git clone https://example.com/x.git')"
expect_allow "通常のコマンドは素通し"                      "$(bash_input 'ls')"
expect_allow "git の範囲演算子は親ディレクトリ扱いしない"  "$(bash_input 'git log main..HEAD')"
expect_allow "origin への git push は素通し"               "$(bash_input 'git push origin main')"
expect_allow "プロジェクト内の絶対パスは素通し"            "$(read_input "$ROOT/README.md")"
expect_allow "/dev 配下は素通し"                           "$(read_input '/dev/null')"
expect_block_exit2 "jq が無ければ exit 2 で拒否"           "$(read_input '../etc/passwd')" "$tmp/nojq"
expect_block_exit2 "壊れた入力は exit 2 で拒否"            'not json' "$PATH"
expect_block_exit2 "空の入力は exit 2 で拒否"              '' "$PATH"
expect_block_exit2 "空白だけの入力は exit 2 で拒否"        '   ' "$PATH"
expect_block_exit2 "null は exit 2 で拒否"                 'null' "$PATH"
expect_block_exit2 "tool_name の無いオブジェクトは exit 2 で拒否" '{}' "$PATH"
expect_block_exit2 "JSON が 2 つ続く入力は exit 2 で拒否" "$(bash_input 'ls')$(bash_input 'ls')" "$PATH"
expect_block_exit2 "cat が無ければ exit 2 で拒否"          "$(bash_input 'ls')" "$tmp/nocat"

if [ "$failures" -gt 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all check-sensitive-paths tests passed"
