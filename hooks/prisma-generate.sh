#!/bin/bash
# PostToolUse hook: Run `prisma generate` after editing schema.prisma.
# Register in settings.json hooks under PostToolUse:
#   {
#     "matcher": "tool == \"Edit\" && tool_input.file_path matches \"prisma/schema\\\\.prisma$\"",
#     "hooks": [{ "type": "command", "command": ".claude/hooks/prisma-generate.sh" }]
#   }

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

if [[ "$file_path" != *"prisma/schema.prisma" ]]; then
  echo "$input"
  exit 0
fi

# Walk up to find package.json (project root)
project_root=$(dirname "$file_path")
while [ "$project_root" != "/" ] && [ ! -f "$project_root/package.json" ]; do
  project_root=$(dirname "$project_root")
done

if [ ! -f "$project_root/package.json" ]; then
  echo "$input"
  exit 0
fi

# Run prisma generate; suppress output to keep log clean, but report failure
if command -v npx >/dev/null 2>&1; then
  if (cd "$project_root" && npx --no-install prisma generate >/dev/null 2>&1); then
    echo "[Hook] prisma generate: OK" >&2
  else
    echo "[Hook] prisma generate: FAILED -- run 'npx prisma generate' manually" >&2
  fi
fi

echo "$input"
