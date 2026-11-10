#!/usr/bin/env bash
# claude-global/statusline.sh の振る舞いテスト。
# コストは Claude Code が集計する cost.total_cost_usd（セッション累計の推定額）を
# そのまま表示し、effort.level があればモデル名の横に出すことを確かめる。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUSLINE="$ROOT/claude-global/statusline.sh"
failures=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1: $2"; failures=$((failures + 1)); }

# 入力 JSON の土台。$1 に jq の式を渡して上書きする
make_input() {
  jq -nc --arg root "$ROOT" "{
    model: {display_name: \"Opus\"},
    workspace: {current_dir: \$root},
    context_window: {
      total_input_tokens: 15500, total_output_tokens: 1200,
      context_window_size: 200000,
      current_usage: {input_tokens: 8000, cache_creation_input_tokens: 2000, cache_read_input_tokens: 10000}
    }
  } | $1"
}

# ANSI の色コードを除いた出力
run() {
  local out status
  out="$(printf '%s' "$1" | env ${STATUSLINE_LANG:+LANG="$STATUSLINE_LANG" LC_ALL="$STATUSLINE_LANG"} "$STATUSLINE" 2>&1)"
  status=$?
  printf '%s\n' "$out" | sed $'s/\033\\[[0-9;]*m//g'
  return $status
}

expect_contains() {
  local name="$1" input="$2" needle="$3" out
  if out="$(run "$input")" && [[ "$out" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 and \"$needle\" in: $out"
  fi
}

expect_absent() {
  local name="$1" input="$2" needle="$3" out
  if out="$(run "$input")" && [[ "$out" != *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 and no \"$needle\" in: $out"
  fi
}

expect_contains "コストは cost.total_cost_usd を小数 2 桁で出す" "$(make_input '.cost = {total_cost_usd: 1.234}')" '$1.23'
expect_contains "cost が無ければ \$0.00"                        "$(make_input '.')" '$0.00'
expect_contains "effort.level をモデル名の横に出す"              "$(make_input '.effort = {level: "high"}')" 'Opus (high)'
expect_absent   "effort が無ければ括弧を出さない"                "$(make_input '.')" 'Opus ('
expect_contains "current_usage が null でも表示する"             "$(make_input '.context_window.current_usage = null')" '░░░░░░░░░░ 0%'

# grep -q で途中終了すると pipefail で失敗扱いになるので、出力を受けてから見る
if [[ "$(locale -a 2>/dev/null)" == *de_DE* ]]; then
  STATUSLINE_LANG=de_DE.UTF-8 expect_contains "小数点がカンマのロケールでも \$1.23" "$(make_input '.cost = {total_cost_usd: 1.234}')" '$1.23'
else
  echo "skip - de_DE ロケールが無いので小数点のロケール確認を省略"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all statusline tests passed"
