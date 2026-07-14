#!/usr/bin/env python3
"""Continuous Learning v2 - observation hook.

Reads a Claude Code hook payload (JSON) from stdin and appends a
normalized observation to ~/.claude/homunculus/observations.jsonl.

Invoked by observe.sh with the event kind as argv[1]:
  pre    -> PreToolUse       -> tool_start
  post   -> PostToolUse      -> tool_complete
  prompt -> UserPromptSubmit -> user_prompt
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

CONFIG_DIR = Path.home() / ".claude" / "homunculus"
OBS_FILE = CONFIG_DIR / "observations.jsonl"
SKILL_DIR = Path(__file__).resolve().parent.parent

EVENTS = {"pre": "tool_start", "post": "tool_complete", "prompt": "user_prompt"}
TRUNCATE_AT = 5000


def load_observation_config():
    try:
        cfg = json.loads((SKILL_DIR / "config.json").read_text())
        return cfg.get("observation", {})
    except Exception:
        return {}


def truncate(value):
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False, default=str)
    return text[:TRUNCATE_AT]


def archive_if_large(max_mb):
    if OBS_FILE.exists() and OBS_FILE.stat().st_size >= max_mb * 1024 * 1024:
        archive_dir = CONFIG_DIR / "observations.archive"
        archive_dir.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        OBS_FILE.rename(archive_dir / f"observations-{stamp}.jsonl")


def build_observation(event, data, obs_cfg):
    observation = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "event": event,
        "session": data.get("session_id", "unknown"),
    }

    if event == "user_prompt":
        prompt = data.get("prompt", "")
        if not prompt:
            return None
        observation["prompt"] = truncate(prompt)
        return observation

    tool = data.get("tool_name") or data.get("tool") or "unknown"
    if tool in set(obs_cfg.get("ignore_tools", [])):
        return None
    capture = obs_cfg.get("capture_tools")
    if capture and tool not in capture:
        return None
    observation["tool"] = tool
    if event == "tool_start":
        observation["input"] = truncate(data.get("tool_input", {}))
    else:
        observation["output"] = truncate(data.get("tool_response", data.get("tool_output", "")))
    return observation


def main():
    event = EVENTS.get(sys.argv[1] if len(sys.argv) > 1 else "pre")
    if event is None:
        return
    try:
        data = json.load(sys.stdin)
    except Exception:
        return

    obs_cfg = load_observation_config()
    if not obs_cfg.get("enabled", True):
        return

    observation = build_observation(event, data, obs_cfg)
    if observation is None:
        return

    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    archive_if_large(obs_cfg.get("max_file_size_mb", 10))
    with OBS_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(observation, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
