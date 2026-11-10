#!/bin/bash
# Bash command checks for check-sensitive-paths.sh, which sources this file
# and provides deny, fail_closed, the path helpers (is_allowed_abs,
# has_parent_ref, check_physical, is_protected_path, expand_braces), and the
# constants they use. Keep both files together in .claude/hooks/.

# --- Bash: words --------------------------------------------------------------

# One operand (a word or a piece of one). An absolute path outside the
# allowed places is denied when its first component exists (/etc, /Users,
# /*), so regex-like words such as /api/ in a grep pattern still pass. A path
# under an existing first component is resolved through symlinks, even when
# the file itself does not exist yet (echo x > linkdir/new).
check_bash_operand() {
  local w=$1 top
  [ -z "$w" ] && return 0
  has_parent_ref "$w" && deny "Access to parent directory is prohibited"
  [[ "$w" == "~"* || "$w" == *":~"* ]] && deny "Access to home directory is prohibited"
  is_protected_path "$w" && deny "Access to git config, git hooks, or Claude Code hooks/settings is prohibited: $w"
  if [[ "$w" == /* ]]; then
    if ! is_allowed_abs "$w"; then
      top=${w#/}
      top=${top%%/*}
      if [ -z "$top" ] || [ -e "/$top" ] || compgen -G "/$top" >/dev/null 2>&1; then
        deny "Access outside working directory is prohibited: $w"
      fi
      return 0
    fi
    check_physical "$w"
  elif [[ "$w" == */* ]]; then
    if [ -e "${w%%/*}" ] || [ -L "${w%%/*}" ]; then check_physical "$w"; fi
  elif [ -L "$w" ]; then
    check_physical "$w"
  fi
  return 0
}

# The paths inside one (brace-expanded) word: the word itself, the path of
# file://..., the value stuck to a short option (-C..), and every piece
# between = @ and , (VAR=a=/x, -F f=@/x, --data @../x).
check_word_paths() {
  local w=$1 piece
  check_bash_operand "$w"
  [[ "$w" == *file://* ]] && check_bash_operand "${w#*file://}"
  [[ "$w" == -[A-Za-z]?* ]] && check_bash_operand "${w:2}"
  if [[ "$w" == *[=@,]* ]]; then
    local IFS='=@,'
    for piece in $w; do
      check_bash_operand "$piece"
      [[ "$piece" == *file://* ]] && check_bash_operand "${piece#*file://}"
    done
  fi
  return 0
}

# Environment assignments (also as export / declare / env arguments). HOME and
# XDG_CONFIG_HOME move git's global config; GIT_* variables can point git at
# other config, repositories, or programs, so only harmless ones pass, and the
# pager / editor values are checked as commands.
check_env_assignment() {
  case "$1" in
    HOME=*|XDG_CONFIG_HOME=*)
      deny "Changing HOME or XDG_CONFIG_HOME is prohibited (git reads its config there)" ;;
    GIT_PAGER=*|GIT_EDITOR=*|GIT_SEQUENCE_EDITOR=*)
      check_bash_command "${1#*=}" $((depth + 1)) ;;
    GIT_TERMINAL_PROMPT=*|GIT_AUTHOR_*=*|GIT_COMMITTER_*=*|GIT_TRACE*=*|\
    GIT_OPTIONAL_LOCKS=*|GIT_MERGE_AUTOEDIT=*|GIT_ADVICE=*|GIT_LFS_SKIP_SMUDGE=*|GIT_FLUSH=*)
      ;;
    GIT_*=*)
      deny "git environment variable is not on the allowed list: ${1%%=*}" ;;
  esac
  return 0
}

check_bash_word() {
  local w=$1 e
  local -a BRACE_OUT=()
  check_env_assignment "$w"
  if [[ "$w" == *\{*..*\}* && "$w" == */* ]]; then
    deny "Brace sequences in paths are prohibited: $w"
  fi
  if [[ "$w" == *\{*,*\}* ]]; then expand_braces "$w"; else BRACE_OUT=("$w"); fi
  for e in "${BRACE_OUT[@]}"; do
    check_word_paths "$e"
  done
  return 0
}

# --- Bash: git ----------------------------------------------------------------

# 0 when config key $1 (or key=value) is on the allowed list. Everything else
# is denied for git -c, --config-env, and git config writes: remote, url,
# branch, alias, include, core.pager / editor / sshCommand / hooksPath and the
# like can send a push elsewhere or run a hidden command.
is_safe_config_key() {
  local key=${1%%=*} ok=1
  shopt -s nocasematch
  case "$key" in
    user.*|color.*|advice.*|log.*|status.*|i18n.*|core.quotepath|core.autocrlf|\
    core.safecrlf|core.filemode|core.ignorecase|commit.gpgsign|tag.gpgsign|\
    init.defaultbranch|pull.rebase|pull.ff|push.default|push.autosetupremote|\
    rebase.autostash|merge.conflictstyle|diff.renames|diff.noprefix|\
    format.pretty|fetch.prune|column.ui|gc.auto|maintenance.auto)
      ok=0 ;;
  esac
  shopt -u nocasematch
  return $ok
}

deny_unless_origin() {
  [ "$1" = origin ] || deny "git push to remotes other than origin is prohibited"
}

# git push [options] [<remote> [<refspec>...]]: the remote must be origin, and
# only known options pass anywhere on the line (git accepts abbreviations such
# as --rep= and bundles such as -uo, so anything else fails closed). With no
# remote, git uses the branch's push remote or upstream; changing those needs
# a remote or config change, HOME / XDG_CONFIG_HOME / GIT_* variables, or a
# write to .git/config, which this hook denies where it can see them. It
# trusts the name "origin", though: git -C <a git directory written
# elsewhere> push origin goes wherever that directory's origin points.
check_git_push() {
  local remote_seen=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -u|--set-upstream|-f|--force|--force-if-includes|--no-force-if-includes|\
      --force-with-lease|--force-with-lease=*|--no-force-with-lease|--tags|\
      --follow-tags|--no-follow-tags|--verify|--no-verify|-n|--dry-run|-d|\
      --delete|-v|--verbose|-q|--quiet|--atomic|--no-atomic|--porcelain|\
      --progress|--no-progress|--all|--branches|--prune|--mirror|--thin|\
      --no-thin|--signed|--signed=*|--no-signed|--recurse-submodules=*|\
      --no-recurse-submodules|-4|-6|--ipv4|--ipv6|--push-option=*) ;;
      -o|--push-option) shift ;;
      --repo=*) deny_unless_origin "${1#--repo=}" ;;
      --repo) shift; deny_unless_origin "${1:-}" ;;
      --) shift; [ $remote_seen = 1 ] || deny_unless_origin "${1:-origin}"; return 0 ;;
      -*) deny "git push option is not on the allowed list: $1" ;;
      *) [ $remote_seen = 1 ] || deny_unless_origin "$1"; remote_seen=1 ;;
    esac
    [ $# -gt 0 ] && shift
  done
  return 0
}

check_git_remote() {
  while [ $# -gt 0 ]; do
    case "$1" in
      add|set-url|rename) deny "git remote $1 is prohibited (security risk)" ;;
      -*) shift ;;
      *) return 0 ;;
    esac
  done
  return 0
}

# 0 when $1 looks like a repository URL: scheme://... or user@host:path.
is_repo_url() {
  [[ "$1" == *://* ]] && return 0
  [[ "$1" == *@*:* && "${1%%:*}" != */* ]]
}

# clone / ls-remote / submodule: no argument may be a repository (scheme://,
# user@host:, or host:path). fetch / pull / archive: the repository is the
# first argument (later ones are refspecs such as main:main); a scheme:// or
# user@host: URL is denied anywhere, including --remote=.
check_git_urls() {
  local mode=$1 w first=1
  shift
  for w in "$@"; do
    is_repo_url "$w" && deny "git from external repositories is prohibited: $w"
    [[ "$w" == -* ]] && continue
    if [ "$mode" = all ] || [ $first = 1 ]; then
      [[ "$w" == *:* && "${w%%:*}" != */* ]] && deny "git from external repositories is prohibited: $w"
    fi
    first=0
  done
  return 0
}

# git config writes (a key followed by a value) must use a key on the allowed
# list; renaming or removing sections is denied. Reads and unsets pass.
check_git_config() {
  local w
  local -a args=()
  for w in "$@"; do
    case "$w" in --get*|--list|-l|--unset*|-e|--edit) return 0 ;; esac
  done
  while [ $# -gt 0 ]; do
    case "$1" in
      --rename-section|--remove-section|rename-section|remove-section)
        deny "git config section renames and removals are prohibited (security risk)" ;;
      -f|--file|--blob|--type|--default|--comment|--value) shift ;;
      -*) ;;
      get|list|unset|edit) [ ${#args[@]} -eq 0 ] && return 0; args+=("$1") ;;
      set) [ ${#args[@]} -eq 0 ] || args+=("$1") ;;
      *) args+=("$1") ;;
    esac
    [ $# -gt 0 ] && shift
  done
  [ ${#args[@]} -ge 2 ] || return 0
  is_safe_config_key "${args[0]}" || deny "git config must not set ${args[0]} (not on the allowed list)"
  return 0
}

# Subcommands that run a command string: check the string as a command line.
check_git_runs_command() {
  local sub=$1 w
  shift
  case "$sub" in
    rebase|difftool)
      while [ $# -gt 0 ]; do
        case "$1" in
          -x|--exec|--extcmd) shift; check_bash_command "${1:-}" $((depth + 1)) ;;
          --exec=*|--extcmd=*) check_bash_command "${1#*=}" $((depth + 1)) ;;
        esac
        [ $# -gt 0 ] && shift
      done ;;
    submodule)
      while [ $# -gt 0 ] && [ "$1" != foreach ]; do shift; done
      [ $# -gt 0 ] || return 0
      shift
      while [[ "${1:-}" == -* ]]; do shift; done
      check_bash_command "$*" $((depth + 1)) ;;
    bisect)
      [ "${1:-}" = run ] || return 0
      shift
      check_bash_command "$*" $((depth + 1)) ;;
    grep)
      for w in "$@"; do
        case "$w" in -O*|--open-files-in-pager*) deny "git grep -O runs a command; prohibited" ;; esac
      done ;;
  esac
  return 0
}

# git lfs push sends objects to a remote: it must be origin too.
check_git_lfs() {
  [ "${1:-}" = push ] || return 0
  shift
  while [[ "${1:-}" == -* ]]; do shift; done
  deny_unless_origin "${1:-origin}"
}

# A user alias (git p = push) runs another command: check its expansion. A
# name that is neither on the subcommand list nor an alias is denied.
check_git_alias() {
  local sub=$1 expansion
  shift
  expansion=$(git -C "$WORK_DIR" config --get "alias.$sub" 2>/dev/null)
  [ -n "$expansion" ] || deny "git subcommand is not on the allowed list: $sub"
  if [[ "$expansion" == '!'* ]]; then
    check_bash_command "${expansion#!} $*" $((depth + 1))
  else
    check_bash_command "git $expansion $*" $((depth + 1))
  fi
}

# Arguments: the words after "git". Only known global options pass (-c and
# --config-env keys must be on the allowed list); then dispatch on the
# subcommand. Subcommands not listed (send-email, imap-send, svn, p4, daemon,
# filter-branch, ...) can only run as a user alias.
check_git() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -c|--config-env)
        shift
        is_safe_config_key "${1:-}" || deny "git -c ${1%%=*} is not on the allowed list" ;;
      --config-env=*)
        is_safe_config_key "${1#*=}" || deny "git --config-env ${1#*=} is not on the allowed list" ;;
      -C|--git-dir|--work-tree|--namespace|--super-prefix|--attr-source) shift ;;
      --git-dir=*|--work-tree=*|--namespace=*|--super-prefix=*|--attr-source=*|--list-cmds=*) ;;
      -p|-P|--paginate|--no-pager|--bare|--no-replace-objects|--no-lazy-fetch|\
      --literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs|\
      --no-optional-locks|--no-advice|-v|--version|-h|--help|--exec-path|\
      --html-path|--man-path|--info-path) ;;
      -*) deny "git option is not on the allowed list: $1" ;;
      *) break ;;
    esac
    [ $# -gt 0 ] && shift
  done
  [ $# -gt 0 ] || return 0
  local sub=$1
  shift
  case "$sub" in
    push) check_git_push "$@" ;;
    remote) check_git_remote "$@" ;;
    clone|ls-remote) check_git_urls all "$@" ;;
    submodule) check_git_urls all "$@"; check_git_runs_command submodule "$@" ;;
    fetch|pull|archive) check_git_urls first "$@" ;;
    config) check_git_config "$@" ;;
    lfs) check_git_lfs "$@" ;;
    rebase|difftool|bisect|grep) check_git_runs_command "$sub" "$@" ;;
    status|log|diff|show|add|commit|checkout|switch|branch|merge|stash|tag|\
    reset|restore|rm|mv|cherry-pick|revert|worktree|rev-parse|rev-list|\
    ls-files|ls-tree|cat-file|blame|init|describe|shortlog|reflog|clean|apply|\
    am|format-patch|notes|for-each-ref|symbolic-ref|update-ref|merge-base|\
    name-rev|count-objects|gc|fsck|prune|show-ref|check-ignore|check-attr|\
    diff-tree|diff-files|diff-index|hash-object|sparse-checkout|range-diff|\
    help|version|var|maintenance|mergetool|whatchanged|cherry|show-branch|\
    update-index|write-tree|read-tree|commit-tree|mktree|verify-commit|\
    verify-tag|interpret-trailers|column|stripspace|check-ref-format|\
    request-pull|annotate|citool|gui|gitk) ;;
    *) check_git_alias "$sub" "$@" ;;
  esac
  return 0
}

# --- Bash: simple commands ----------------------------------------------------

is_shell_word() {
  case "${1##*/}" in sh|bash|zsh|dash|ksh|mksh|fish|eval) return 0 ;; esac
  return 1
}

# 0 when the simple command "$@" hands text to a shell: a shell or eval word
# anywhere (cat x | sh, xargs sh -c), or . / source as the command itself.
command_runs_shell() {
  local w
  case "${1:-}" in builtin|command) shift ;; esac
  case "${1:-}" in .|source) return 0 ;; esac
  for w in "$@"; do
    is_shell_word "$w" && return 0
  done
  return 1
}

# 0 when the words "$@" are cd with no directory (cd, cd -P, cd --,
# builtin cd, command -p cd), which goes to $HOME.
is_bare_cd() {
  case "${1:-}" in
    builtin|command) shift; while [[ "${1:-}" == -* ]]; do shift; done ;;
  esac
  [ "${1:-}" = cd ] || return 1
  shift
  local w
  for w in "$@"; do
    [[ "$w" == -* ]] || return 1
  done
  return 0
}

# sh / bash / ... -c [--] STRING, and eval ARGS: the string is a command line.
check_nested_shell() {
  local w after_shell=0
  while [ $# -gt 0 ]; do
    w=$1
    shift
    if [ "$w" = eval ]; then
      check_bash_command "$*" $((depth + 1))
      return 0
    fi
    if is_shell_word "$w"; then
      after_shell=1
    elif [ $after_shell = 1 ] && [[ "$w" == -* && "$w" != --* && "$w" == *c* ]]; then
      [ "${1:-}" = -- ] && shift
      check_bash_command "${1:-}" $((depth + 1))
      after_shell=0
    fi
  done
  return 0
}

# Arguments: the words of one simple command (redirection targets excluded).
check_simple_command() {
  local w
  for w in "$@"; do
    check_bash_word "$w"
  done
  is_bare_cd "$@" && deny "Access to home directory is prohibited (cd without a directory)"
  check_nested_shell "$@"
  # Every git word, not just the first (sudo -u git git push ...)
  while [ $# -gt 0 ]; do
    w=$1
    shift
    case "$w" in
      git|*/git) check_git "$@" ;;
    esac
  done
  return 0
}

# --- Bash: tokenizer ----------------------------------------------------------
# check_bash_command walks the command one character (or one plain run) at a
# time. The scan_* and end_* functions below, and the checks that recurse
# through depth, must only be called from inside it: they read and write its
# locals through bash's dynamic scope.
#   cmd, n, i, c    the text, its length, the position, the character
#   depth, stop     nesting level; ")" when inside $( ), else empty
#   q               quote state: "" ' " $' or h (heredoc body: like ", but "
#                   is literal and nothing is a command word)
#   data_only       1 in heredoc bodies: only substitutions are checked
#   word, have_word, word_quoted   the word being built
#   words           words of the current simple command
#   redirect        what the next word is: none / target / herestring / heredoc
#   heredocs        pending heredoc delimiters ("strip:quoted:EOF")
#   herestrings     here-string words of the current simple command
#   heredoc_strip   1 after <<- (strip leading tabs)
#   ansi            raw text of a $'...' quote
#   line_shell      1 when a command on this line hands text to a shell
#   parens          unclosed ( inside $( )
#   done_scan       1 once the closing ) of $( ) is reached
# SUBST_END (global) returns the index of that ) to the caller.

end_word() {
  [ "$have_word" = 1 ] || return 0
  if [ "$data_only" = 0 ]; then
    case "$redirect" in
      target) check_bash_word "$word" ;;
      herestring) herestrings+=("$word") ;;
      heredoc) heredocs+=("$heredoc_strip:$word_quoted:$word") ;;
      *)
        # zsh expands =name to the path of name (=git is git)
        [[ "$word" == =[A-Za-z]* ]] && word=${word#=}
        words+=("$word") ;;
    esac
  fi
  redirect=none
  word=""
  have_word=0
  word_quoted=0
}

end_command() {
  local h
  end_word
  redirect=none
  if [ ${#words[@]} -gt 0 ]; then
    check_simple_command "${words[@]}"
    if command_runs_shell "${words[@]}"; then
      line_shell=1
      for h in "${herestrings[@]}"; do
        check_bash_command "$h" $((depth + 1))
      done
    fi
  fi
  words=()
  herestrings=()
}

# After an unquoted newline: read the bodies of pending heredocs. A body goes
# to a shell when a command on the line runs one (bash <<X, cat <<X | sh):
# then it is checked as commands. Otherwise it is data, but with an unquoted
# delimiter its $( ) and backquotes still run, so those are checked.
end_line() {
  local d strip quoted delim line body rest
  for d in "${heredocs[@]}"; do
    strip=${d%%:*}
    d=${d#*:}
    quoted=${d%%:*}
    delim=${d#*:}
    body=""
    while [ $((i + 1)) -lt $n ]; do
      rest=${cmd:i+1}
      line=${rest%%"$NL"*}
      i=$((i + 1 + ${#line}))
      if [ "$strip" = 1 ]; then
        while [[ "$line" == "$TAB"* ]]; do line=${line#"$TAB"}; done
      fi
      [ "$line" = "$delim" ] && break
      body+="$line$NL"
    done
    if [ "$line_shell" = 1 ]; then
      check_bash_command "$body" $((depth + 1))
    elif [ "$quoted" = 0 ]; then
      check_bash_command "$body" $((depth + 1)) 0 "" h
    fi
  done
  heredocs=()
  line_shell=0
}

# i is at an unquoted or double-quoted "$": $HOME and ${HOME...} expand to home.
check_dollar_home() {
  local next
  [ "$data_only" = 1 ] && return 0
  if [ "${cmd:i:5}" = '$HOME' ]; then
    next=${cmd:i+5:1}
  elif [ "${cmd:i:6}" = '${HOME' ]; then
    next=${cmd:i+6:1}
  else
    return 0
  fi
  [[ "$next" == [A-Za-z0-9_] ]] || deny "Access to home directory is prohibited"
}

# i is at "$(": the substituted text is checked as its own command line (the
# same tokenizer, so quotes, heredocs, and nesting work), then i moves to the
# closing ).
scan_substitution() {
  check_bash_command "$cmd" $((depth + 1)) $((i + 2)) ')'
  i=$SUBST_END
  have_word=1
}

# i is at an opening backquote. bash removes the \ before \ ` and $ in the
# quoted text first, then runs it as a command line (so \` nests); the text is
# checked the same way.
scan_backquote() {
  local j=$((i + 1)) body="" ch
  while [ $j -lt $n ]; do
    ch=${cmd:j:1}
    if [ "$ch" = '\' ]; then
      case "${cmd:j+1:1}" in
        '\'|'`'|'$') body+=${cmd:j+1:1} ;;
        *) body+="$ch${cmd:j+1:1}" ;;
      esac
      j=$((j + 2))
      continue
    fi
    [ "$ch" = '`' ] && break
    body+=$ch
    j=$((j + 1))
  done
  [ $j -lt $n ] || deny "Unterminated command substitution"
  check_bash_command "$body" $((depth + 1))
  i=$j
  have_word=1
}

# i is at the first character of a redirection operator (< > &> and so on). A
# digit-only word right before it is a file descriptor, not an argument.
scan_redirect() {
  [ "$have_word" = 1 ] && [[ "$word" =~ ^[0-9]+$ ]] && { word=""; have_word=0; }
  end_word
  local op=$c
  while :; do
    case "${cmd:i+1:1}" in
      '<'|'>'|'&'|'|') op+=${cmd:i+1:1}; i=$((i + 1)) ;;
      '-') [[ "$op" == '<<' || "$op" == *'&' ]] || break
           op+=-; i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  case "$op" in
    '<<') redirect=heredoc; heredoc_strip=0 ;;
    '<<-') redirect=heredoc; heredoc_strip=1 ;;
    '<<<') redirect=herestring ;;
    *'&-') redirect=none ;;   # >&- closes a descriptor; the next word is an argument
    *) redirect=target ;;
  esac
}

# '...': copy everything up to the closing quote at once.
scan_single() {
  local rest=${cmd:i} chunk
  chunk=${rest%%"$SQ"*}
  word+=$chunk
  i=$((i + ${#chunk}))
  [ $i -lt $n ] && q=""
}

scan_double() {
  local rest chunk
  case "$c" in
    '"') if [ "$q" = h ]; then word+=$c; else q=""; fi ;;
    '\')
      case "${cmd:i+1:1}" in
        '$'|'`'|'"'|'\') word+=${cmd:i+1:1}; i=$((i + 1)) ;;
        "$NL") i=$((i + 1)) ;;
        *) word+=$c ;;
      esac ;;
    '$')
      check_dollar_home
      if [ "${cmd:i+1:1}" = '(' ]; then scan_substitution; else word+=$c; fi ;;
    '`') scan_backquote ;;
    *)
      rest=${cmd:i}
      chunk=${rest%%$DQ_STOP*}
      word+=$chunk
      i=$((i + ${#chunk} - 1)) ;;
  esac
}

# $'...': collect up to the closing quote, then decode the escapes so the word
# is checked as it will run. bash 3.2 keeps unknown escapes (\.) that zsh and
# newer bash drop, so remaining backslashes are dropped too; \u \U \c are
# denied rather than decoded.
scan_ansi() {
  local decoded
  case "$c" in
    "'")
      case "$ansi" in
        *'\u'*|*'\U'*|*'\c'*) deny "\$'...' with \\u, \\U, or \\c escapes is prohibited" ;;
      esac
      ansi=${ansi//"\\'"/"'"}
      ansi=${ansi//'\"'/'"'}
      printf -v decoded '%b' "$ansi"
      word+=${decoded//\\/}
      ansi=""
      q="" ;;
    '\') ansi+="$c${cmd:i+1:1}"; i=$((i + 1)) ;;
    *) ansi+=$c ;;
  esac
}

scan_unquoted() {
  case "$c" in
    "'") q="'"; have_word=1; word_quoted=1 ;;
    '"') q='"'; have_word=1; word_quoted=1 ;;
    '\')
      if [ "${cmd:i+1:1}" != "$NL" ]; then word+=${cmd:i+1:1}; have_word=1; word_quoted=1; fi
      i=$((i + 1)) ;;
    '$')
      check_dollar_home
      case "${cmd:i+1:1}" in
        "'") q="\$'"; ansi=""; have_word=1; word_quoted=1; i=$((i + 1)) ;;
        '"') q='"'; have_word=1; word_quoted=1; i=$((i + 1)) ;;
        '(') scan_substitution ;;
        *) word+=$c; have_word=1 ;;
      esac ;;
    '`') scan_backquote ;;
    ' '|"$TAB") end_word ;;
    "$NL") end_command; end_line ;;
    ';') end_command ;;
    '(') end_command; parens=$((parens + 1)) ;;
    ')')
      end_command
      if [ "$stop" = ')' ] && [ $parens -eq 0 ]; then
        done_scan=1
      elif [ $parens -gt 0 ]; then
        parens=$((parens - 1))
      fi ;;
    '|') [ "${cmd:i+1:1}" = '&' ] && i=$((i + 1)); end_command ;;
    '&') if [ "${cmd:i+1:1}" = '>' ]; then scan_redirect; else end_command; fi ;;
    '<'|'>') scan_redirect ;;
    '#') if [ "$have_word" = 1 ]; then word+=$c; else skip_comment; fi ;;
    *) word+=$c; have_word=1 ;;
  esac
}

skip_comment() {
  while [ $((i + 1)) -lt $n ] && [ "${cmd:i+1:1}" != "$NL" ]; do i=$((i + 1)); done
}

# Arguments: command text, nesting depth, start index, ")" when inside $( ),
# and the starting quote state (h for a heredoc body). Sets SUBST_END to the
# index of the closing ) when inside $( ).
check_bash_command() {
  local cmd=$1 depth=${2:-0} i=${3:-0} stop=${4:-} q=${5:-}
  [ "$depth" -le "$MAX_DEPTH" ] || deny "Command nesting is too deep to check"
  local n=${#cmd} c word="" have_word=0 word_quoted=0 redirect=none heredoc_strip=0
  local ansi="" line_shell=0 parens=0 done_scan=0 data_only=0
  local -a words=() heredocs=() herestrings=()
  [ "$q" = h ] && data_only=1
  while [ $i -lt $n ] && [ $done_scan = 0 ]; do
    c=${cmd:i:1}
    case "$q" in
      "'") scan_single ;;
      '"'|h) scan_double ;;
      "\$'") scan_ansi ;;
      *) scan_unquoted ;;
    esac
    [ $done_scan = 1 ] || i=$((i + 1))
  done
  [ -z "$q" ] || [ "$q" = h ] || deny "Unterminated quote in command"
  [ -z "$stop" ] || [ $done_scan = 1 ] || deny "Unterminated command substitution"
  end_command
  [ -n "$stop" ] && SUBST_END=$i
  return 0
}
