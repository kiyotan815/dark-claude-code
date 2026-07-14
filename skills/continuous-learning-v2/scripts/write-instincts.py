#!/usr/bin/env python3
"""Write instinct files produced by the observer's analysis output.

Reads the observer session's stdout from stdin, extracts the JSON array of
{filename, content} objects, and writes them under
~/.claude/homunculus/instincts/personal/. Tolerates prose around the JSON.

Keeping writes here (instead of in the headless session) means the observer
needs no write permissions and can never touch anything outside this
directory.
"""
import json
import re
import sys
from pathlib import Path

PERSONAL_DIR = Path.home() / ".claude" / "homunculus" / "instincts" / "personal"


def extract_json(text):
    start = text.find("[")
    end = text.rfind("]")
    while 0 <= start < end:
        try:
            return json.loads(text[start:end + 1])
        except Exception:
            start = text.find("[", start + 1)
    return None


def main():
    text = sys.stdin.read()
    items = extract_json(text)
    if not isinstance(items, list):
        print("no instinct JSON found in analysis output")
        return
    PERSONAL_DIR.mkdir(parents=True, exist_ok=True)
    written = 0
    for item in items:
        if not isinstance(item, dict):
            continue
        name = str(item.get("filename", "")).strip()
        content = item.get("content", "")
        if not name or not isinstance(content, str) or not content.strip():
            continue
        name = re.sub(r"[^A-Za-z0-9._-]", "-", Path(name).name)
        if not name.endswith(".md"):
            name += ".md"
        (PERSONAL_DIR / name).write_text(content, encoding="utf-8")
        written += 1
    print(f"wrote {written} instinct file(s) to {PERSONAL_DIR}")


if __name__ == "__main__":
    main()
