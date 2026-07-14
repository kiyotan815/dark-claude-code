#!/bin/bash
# Continuous Learning v2 - Observer Launcher
#
# Runs a background loop that periodically analyzes
# ~/.claude/homunculus/observations.jsonl with a headless Haiku session and
# writes instincts to ~/.claude/homunculus/instincts/personal/.
# Started automatically by the SessionStart hook (see SKILL.md);
# safe to call repeatedly (no-op if already running or disabled in config).
#
# Usage:
#   start-observer.sh [start]  # Start observer in background
#   start-observer.sh stop     # Stop running observer
#   start-observer.sh status   # Check observer status
#   start-observer.sh analyze  # Run one analysis pass now (foreground)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SKILL_DIR/config.json"
CONFIG_DIR="${HOME}/.claude/homunculus"
PID_FILE="${CONFIG_DIR}/.observer.pid"
LOG_FILE="${CONFIG_DIR}/observer.log"
OBSERVATIONS_FILE="${CONFIG_DIR}/observations.jsonl"

config_get() { # $1 = python expression over parsed config dict `c`
  python3 -c "import json;c=json.load(open('$CONFIG_FILE'));print($1)" 2>/dev/null
}

enabled="$(config_get "c.get('observer',{}).get('enabled',False)")"
interval_min="$(config_get "c.get('observer',{}).get('run_interval_minutes',5)")"
min_obs="$(config_get "c.get('observer',{}).get('min_observations_to_analyze',20)")"
model="$(config_get "c.get('observer',{}).get('model','haiku')")"

mkdir -p "$CONFIG_DIR"

analyze_observations() {
  obs_count=$(wc -l < "$OBSERVATIONS_FILE" 2>/dev/null | tr -d ' ' || echo 0)
  if [ "${obs_count:-0}" -lt "${min_obs:-20}" ]; then
    return 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    echo "[$(date)] claude CLI not found; skipping analysis" >> "$LOG_FILE"
    return 0
  fi
  echo "[$(date)] Analyzing $obs_count observations..." >> "$LOG_FILE"
  # CLAUDE_OBSERVER=1 keeps observe.sh from logging the analysis session itself.
  # The headless session is read-only: it outputs instincts as JSON and
  # write-instincts.py persists them (~/.claude/** is config-protected, so the
  # session itself could not write there without interactive approval).
  (
    cd "$CONFIG_DIR" &&
    CLAUDE_OBSERVER=1 claude --model "${model:-haiku}" --max-turns 15 -p \
      "You are the continuous-learning observer. Follow the pattern-detection spec in $SCRIPT_DIR/observer.md. Read observations.jsonl in the current directory and look for repeated patterns: user corrections, error resolutions, repeated workflows, tool preferences. Also read existing instinct files under instincts/personal/ and update them (merge evidence, adjust confidence) instead of duplicating. Then output ONLY a JSON array, no markdown fences and no prose: [{\"filename\": \"<kebab-case-id>.md\", \"content\": \"<full instinct markdown with frontmatter: id, trigger, confidence, domain, source>\"}]. Only include instincts for clear patterns (3+ occurrences); if none, output []. Never include actual code snippets, only patterns."
  ) 2>> "$LOG_FILE" | tee -a "$LOG_FILE" | python3 "$SKILL_DIR/scripts/write-instincts.py" >> "$LOG_FILE" 2>&1 || true
  # Archive processed observations so the next pass starts fresh
  if [ -f "$OBSERVATIONS_FILE" ]; then
    archive_dir="${CONFIG_DIR}/observations.archive"
    mkdir -p "$archive_dir"
    mv "$OBSERVATIONS_FILE" "$archive_dir/processed-$(date +%Y%m%d-%H%M%S).jsonl"
  fi
}

case "${1:-start}" in
  stop)
    if [ -f "$PID_FILE" ]; then
      pid=$(cat "$PID_FILE")
      if kill -0 "$pid" 2>/dev/null; then
        echo "Stopping observer (PID: $pid)..."
        kill "$pid"
        rm -f "$PID_FILE"
        echo "Observer stopped."
      else
        echo "Observer not running (stale PID file)."
        rm -f "$PID_FILE"
      fi
    else
      echo "Observer not running."
    fi
    ;;

  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Observer is running (PID: $(cat "$PID_FILE"))"
      echo "Log: $LOG_FILE"
      echo "Pending observations: $(wc -l < "$OBSERVATIONS_FILE" 2>/dev/null | tr -d ' ' || echo 0)"
    else
      rm -f "$PID_FILE"
      echo "Observer not running"
      exit 1
    fi
    ;;

  analyze)
    min_obs=1
    analyze_observations
    echo "Analysis pass finished. Log: $LOG_FILE"
    ;;

  _daemon)
    # Internal: the actual observer loop, launched detached by `start`
    trap 'rm -f "$PID_FILE"; exit 0' TERM INT
    trap 'analyze_observations' USR1
    echo "$$" > "$PID_FILE"
    echo "[$(date)] Observer started (PID: $$)" >> "$LOG_FILE"
    while true; do
      sleep $(( ${interval_min:-5} * 60 ))
      analyze_observations
    done
    ;;

  start)
    if [ "$enabled" != "True" ]; then
      echo "Observer disabled in config ($CONFIG_FILE)"
      exit 0
    fi
    if [ -f "$PID_FILE" ]; then
      pid=$(cat "$PID_FILE")
      if kill -0 "$pid" 2>/dev/null; then
        echo "Observer already running (PID: $pid)"
        exit 0
      fi
      rm -f "$PID_FILE"
    fi
    # Detach into a new session (setsid) so the daemon survives the parent
    # process group being torn down (hook shells, sandboxed tool calls, ...)
    python3 - "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" << 'PY'
import subprocess, sys
subprocess.Popen(
    ["/bin/bash", sys.argv[1], "_daemon"],
    start_new_session=True,
    stdin=subprocess.DEVNULL,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
PY
    sleep 1
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Observer started (PID: $(cat "$PID_FILE")). Log: $LOG_FILE"
    else
      echo "Failed to start observer"
      exit 1
    fi
    ;;

  *)
    echo "Usage: $0 {start|stop|status|analyze}"
    exit 1
    ;;
esac
