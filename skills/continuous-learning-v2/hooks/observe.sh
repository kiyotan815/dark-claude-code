#!/bin/bash
# Continuous Learning v2 - Observation Hook
#
# Claude Code passes hook data via stdin as JSON; the event kind comes in $1
# (pre / post / prompt). Registration lives in ~/.claude/settings.json
# (shipped in claude-global/settings.json) — see SKILL.md "Quick Start".
#
# Never blocks tool use: every path exits 0.

# Skip observing the observer's own analysis sessions (prevents feedback loops)
[ -n "${CLAUDE_OBSERVER:-}" ] && exit 0

CONFIG_DIR="${HOME}/.claude/homunculus"

# Kill switch: `touch ~/.claude/homunculus/disabled` pauses observation
[ -f "$CONFIG_DIR/disabled" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/observe.py" "${1:-pre}" 2>/dev/null || true
exit 0
