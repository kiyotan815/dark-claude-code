#!/usr/bin/env bash
# hooks/check-sensitive-paths.sh（opt-in の PreToolUse hook）の振る舞いテスト。
# block は PreToolUse の現行形式 hookSpecificOutput.permissionDecision = "deny" の妥当な JSON、
# allow は出力なし・exit 0 であることを確かめる。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$ROOT/hooks/check-sensitive-paths.sh"
export CLAUDE_PROJECT_DIR="$ROOT"
failures=0

run_hook() {
  printf '%s' "$1" | bash "$HOOK"
}

expect_deny() {
  local name="$1" input="$2" out
  out="$(run_hook "$input")"
  if printf '%s' "$out" | jq -e '
      .hookSpecificOutput.hookEventName == "PreToolUse"
      and .hookSpecificOutput.permissionDecision == "deny"
      and (.hookSpecificOutput.permissionDecisionReason | length > 0)' >/dev/null 2>&1; then
    echo "ok   - $name"
  else
    echo "FAIL - $name: expected deny JSON, got: $out"
    failures=$((failures + 1))
  fi
}

expect_allow() {
  local name="$1" input="$2" out status
  out="$(run_hook "$input")"
  status=$?
  if [ "$status" -eq 0 ] && [ -z "$out" ]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name: expected no output and exit 0, got exit $status: $out"
    failures=$((failures + 1))
  fi
}

expect_deny  "Read の親ディレクトリ参照を拒否" \
  '{"tool_name":"Read","tool_input":{"file_path":"../etc/passwd"}}'
expect_deny  "origin 以外への git push を拒否" \
  '{"tool_name":"Bash","tool_input":{"command":"git push upstream main"}}'
expect_deny  "パスに引用符があっても妥当な JSON で拒否" \
  '{"tool_name":"Read","tool_input":{"file_path":"/tmp/x\"y"}}'
expect_deny  "ホームディレクトリ参照を拒否" \
  '{"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/id_rsa"}}'
expect_allow "通常のコマンドは素通し" \
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
expect_allow "git の範囲演算子は親ディレクトリ扱いしない" \
  '{"tool_name":"Bash","tool_input":{"command":"git log main..HEAD"}}'
expect_allow "プロジェクト内の絶対パスは素通し" \
  "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$ROOT/README.md\"}}"

if [ "$failures" -gt 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all check-sensitive-paths tests passed"
