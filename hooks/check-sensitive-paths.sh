#!/bin/bash
# PreToolUse hook: Block access to directories outside the working directory
#
# A best-effort tripwire against prompt injection, not a sandbox. It splits a
# Bash command with bash 3.2's rules before expansion (quotes, escapes, ; | &,
# redirections, heredocs, here-strings, $(...), backquotes, sh -c, eval) and
# checks every word, but it evaluates nothing. Known gaps: values that only
# exist at run time (variables, command output, globs, xargs input), scripts,
# syntax the real shell (often zsh) reads differently (zsh-only expansions,
# case patterns inside $( ), << inside arithmetic), a push to "origin" of a
# git directory written elsewhere, and general network exfiltration (curl,
# nc). The Bash sandbox (including its network limits) and permissions.deny
# are the enforcement.

export LC_ALL=C   # byte-wise string indexing and locale-independent matching
set -f            # word splitting below must never glob

# Block via exit 2 (Claude Code denies the call and shows stderr as the reason).
# Used when the checks below cannot run, so the hook fails closed instead of
# allowing everything with empty fields.
fail_closed() {
  echo "check-sensitive-paths: $1; blocking" >&2
  exit 2
}

# Emit a PreToolUse deny decision and stop. jq escapes the reason, so paths with
# quotes or backslashes still produce valid JSON.
deny() {
  jq -nc --arg reason "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}' \
    || fail_closed "could not build the deny decision ($1)"
  exit 0
}

NL=$'\n'
TAB=$'\t'
SQ="'"
DQ_STOP='["\\$`]'   # characters that end a plain run inside "..."
CLAUDE_TMP_RE='^(/private)?/tmp/claude(-[0-9]+)?(/|$)'
MAX_DEPTH=4
MAX_BRACES=16       # { per word; deep brace recursion can crash bash
MAX_COMMAND_LENGTH=32768

# --- paths --------------------------------------------------------------------

# 0 when absolute path $1 is one the hook allows: the working directory (as
# written or with symlinks resolved), Claude's temp directory (/tmp/claude or
# /tmp/claude-<uid>), and the harmless /dev entries.
is_allowed_abs() {
  [[ "$1" == "$WORK_DIR" || "$1" == "$WORK_DIR"/* ]] && return 0
  [[ "$1" == "$REAL_WORK_DIR" || "$1" == "$REAL_WORK_DIR"/* ]] && return 0
  [[ "$1" =~ $CLAUDE_TMP_RE ]] && return 0
  case "$1" in
    /dev/null|/dev/stdin|/dev/stdout|/dev/stderr|/dev/tty|/dev/zero|/dev/random|/dev/urandom|/dev/fd/*)
      return 0 ;;
  esac
  return 1
}

# 0 when $1 names a parent directory: "..", "../x", "x/../y", or "x/..".
# Git ranges such as main..HEAD, ..HEAD, and HEAD~1.. do not match.
has_parent_ref() {
  [[ "$1" == ".." || "$1" == ../* || "$1" == */../* || "$1" == */.. ]]
}

# Prints the physical path of $1 (relative paths start at $PWD): symlinks in
# its longest existing directory prefix are resolved, the rest is appended as
# written, and a symlink as the last component is followed.
physical_path() {
  local p=$1 head rest="" real
  [[ "$p" == /* ]] || p="$PWD/$p"
  head=$p
  while [ -n "$head" ] && [ ! -d "$head" ]; do
    rest="/${head##*/}$rest"
    head=${head%/*}
  done
  real=$(cd -P -- "${head:-/}" 2>/dev/null && pwd -P) || return 1
  [ "$real" = / ] && real=""
  p="$real$rest"
  if [ -L "$p" ]; then
    p=$(readlink -f -- "$p" 2>/dev/null) || return 1
    [ -n "$p" ] || return 1
  fi
  printf '%s\n' "$p"
}

# Deny when path $1 resolves (through symlinks) outside.
check_physical() {
  local real
  real=$(physical_path "$1") || deny "Failed to resolve path: $1"
  is_allowed_abs "$real" || deny "Path resolves outside working directory: $1 -> $real"
  return 0
}

# 0 when path $1 is one of the files that keep git and this check honest:
# .git itself, .git/config, .git/hooks, .claude/hooks, .claude/settings*.json.
# Matched case-insensitively (as macOS file systems are) after collapsing //
# and /./, so .GIT/config and .git//config count too.
is_protected_path() {
  local p="/$1" dbl=// one=/ dot=/./ found=1
  while [[ "$p" == *"$dbl"* ]]; do p=${p//"$dbl"/$one}; done
  while [[ "$p" == *"$dot"* ]]; do p=${p//"$dot"/$one}; done
  shopt -s nocasematch
  case "$p" in
    */.git|*/.git/config|*/.git/hooks|*/.git/hooks/*|*/.claude/hooks|*/.claude/hooks/*|\
    */.claude/settings.json|*/.claude/settings.local.json)
      found=0 ;;
  esac
  shopt -u nocasematch
  return $found
}

# Appends the brace expansions of $1 to the caller's BRACE_OUT ({a,b} only; a
# word with a {x..y} sequence and a / is denied by the caller).
expand_braces() {
  local w=$1 re='^(.*)\{([^{}]*,[^{}]*)\}(.*)$' pre alts post opens
  opens=${w//[^\{]/}
  [ ${#opens} -le $MAX_BRACES ] || deny "Too many braces in one word to check"
  [ ${#BRACE_OUT[@]} -le 64 ] || deny "Brace expansion is too large to check"
  if [[ "$w" =~ $re ]]; then
    pre=${BASH_REMATCH[1]}
    alts="${BASH_REMATCH[2]},"
    post=${BASH_REMATCH[3]}
    while [ -n "$alts" ]; do
      expand_braces "$pre${alts%%,*}$post"
      alts=${alts#*,}
    done
  else
    BRACE_OUT+=("$w")
  fi
}

# Read / Edit / Write / Grep / Glob / NotebookEdit: one path.
check_file_path() {
  local p=$1
  [ -z "$p" ] && return 0
  [[ "$p" == *".."* ]] && deny "Access to parent directory is prohibited"
  [[ "$p" == "~"* || "$p" == *"~/"* ]] && deny "Access to home directory is prohibited"
  if [[ "$p" == /* ]] && ! is_allowed_abs "$p"; then
    deny "Access outside working directory is prohibited: $p"
  fi
  check_physical "$p"
}

# --- Bash checks (tokenizer, git) live in a sibling file ----------------------

case "$0" in */*) HOOK_DIR=${0%/*} ;; *) HOOK_DIR=. ;; esac
# shellcheck source=check-sensitive-paths-bash.sh
. "$HOOK_DIR/check-sensitive-paths-bash.sh" 2>/dev/null \
  || fail_closed "check-sensitive-paths-bash.sh is missing next to the hook"

# --- main ---------------------------------------------------------------------

# Read tool information from stdin in JSON format
input=$(cat) || fail_closed "could not read hook input"

command -v jq >/dev/null 2>&1 || fail_closed "jq not found"

# Get tool name. The input must be exactly one JSON object with a non-empty
# string tool_name; anything else (empty, null, several values) fails closed.
tool_name=$(printf '%s' "$input" | jq -e -s -r '
    if length == 1 and (.[0] | type) == "object"
    then .[0].tool_name | strings | select(length > 0)
    else error("not a single JSON object") end') \
  || fail_closed "invalid hook input"

# All checks below run in a subshell (see the end of the file).
run_checks() {
  # Project root: Claude Code exports CLAUDE_PROJECT_DIR to hook processes
  WORK_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
  WORK_DIR="${WORK_DIR%/}"
  [ -n "$WORK_DIR" ] || fail_closed "the project directory is /"
  REAL_WORK_DIR=$(cd -P -- "$WORK_DIR" 2>/dev/null && pwd -P) || REAL_WORK_DIR=$WORK_DIR

  # Resolve relative paths where the tool runs
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty') || fail_closed "invalid hook input"
  if [ -n "$cwd" ]; then
    cd -- "$cwd" 2>/dev/null || fail_closed "cwd is not a directory: $cwd"
  fi

  if [ "$tool_name" = "Bash" ]; then
    target=$(printf '%s' "$input" | jq -r '.tool_input.command // ""') \
      || fail_closed "invalid hook input"
    if [ ${#target} -gt $MAX_COMMAND_LENGTH ]; then
      deny "Command is too long to check ($MAX_COMMAND_LENGTH bytes max); write long text with the Write tool"
    fi
    check_bash_command "$target"
  else
    # file_path (Read/Edit/Write), path (Grep/Glob), notebook_path
    # (NotebookEdit), and the Glob pattern, one per line; all must be strings
    paths=$(printf '%s' "$input" | jq -r '
        .tool_input as $i
        | [$i.file_path, $i.path, $i.notebook_path,
           (if .tool_name == "Glob" then $i.pattern else null end)]
        | map(select(. != null))
        | if all(type == "string") then .[] else error("non-string path") end') \
      || fail_closed "invalid hook input"
    IFS=$NL
    for p in $paths; do
      case "$tool_name" in
        Edit|Write|NotebookEdit)
          is_protected_path "$p" && deny "Writing git config, git hooks, or Claude Code hooks/settings is prohibited: $p" ;;
      esac
      BRACE_OUT=()
      if [[ "$p" == *\{*,*\}* ]]; then expand_braces "$p"; else BRACE_OUT=("$p"); fi
      for e in "${BRACE_OUT[@]}"; do
        check_file_path "$e"
      done
    done
  fi
  exit 0
}

# A crash in the checks (bash dies on a signal, for example a stack overflow
# on a crafted word) would exit with a code Claude Code treats as a
# non-blocking error and let the call through, so run them in a subshell and
# turn anything but a clean result into a block. deny() output passes through;
# exit 2 from fail_closed keeps its stderr reason.
result=$(run_checks)
rc=$?
case "$rc" in
  0) [ -n "$result" ] && printf '%s\n' "$result"
     exit 0 ;;
  2) exit 2 ;;
  *) fail_closed "the check exited with status $rc" ;;
esac
