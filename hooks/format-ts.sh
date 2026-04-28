#!/bin/bash
# PostToolUse hook: Format TypeScript/TSX files
# Automatically runs after Write/Edit tool usage

# Read input
INPUT=$(cat)

# Get file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Format only for TypeScript/TSX files
if [[ "$FILE_PATH" =~ \.(ts|tsx)$ ]]; then
  # Run only if prettier is installed
  if command -v npx &> /dev/null; then
    npx prettier --write "$FILE_PATH" 2>/dev/null || true
  fi
fi

# Return success
echo '{"continue": true}'
