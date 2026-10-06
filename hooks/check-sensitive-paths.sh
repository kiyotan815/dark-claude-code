#!/bin/bash
# PreToolUse hook: Block access to directories outside the working directory

# Read tool information from stdin in JSON format
input=$(cat)

# Get tool name
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

# Extract path (command for Bash, file_path for Read/Edit/Write)
if [ "$tool_name" = "Bash" ]; then
  target=$(echo "$input" | jq -r '.tool_input.command // ""')
else
  target=$(echo "$input" | jq -r '.tool_input.file_path // ""')
fi

# Project root: Claude Code exports CLAUDE_PROJECT_DIR to hook processes
WORK_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Symlink check (Read/Edit/Write tools only)
if [ "$tool_name" != "Bash" ] && [ -n "$target" ]; then
  # If file path is a symlink
  if [ -L "$target" ]; then
    # Resolve actual target path
    resolved_path=$(readlink -f "$target" 2>/dev/null)

    # Block if resolution fails
    if [ $? -ne 0 ] || [ -z "$resolved_path" ]; then
      echo "{\"decision\": \"block\", \"reason\": \"Failed to resolve symlink: $target\"}"
      exit 0
    fi

    # Block if resolved path is outside working directory
    if [[ "$resolved_path" != "$WORK_DIR"* ]] && [[ "$resolved_path" != "/tmp/claude"* ]]; then
      echo "{\"decision\": \"block\", \"reason\": \"Symlink points outside working directory: $target -> $resolved_path\"}"
      exit 0
    fi
  fi
fi

# Git command security check (prompt injection protection)
if [ "$tool_name" = "Bash" ]; then
  # Block git remote add (prevent adding attacker's remote repository)
  if [[ "$target" == *"git remote add"* ]]; then
    echo "{\"decision\": \"block\", \"reason\": \"git remote add is prohibited (security risk)\"}"
    exit 0
  fi

  # Block git push to remotes other than origin
  if [[ "$target" == *"git push"* ]]; then
    # Allow if origin is included
    if [[ "$target" == *" origin"* ]]; then
      :  # Allow
    else
      # If origin is not included, check if remote name is specified
      # After "git push", skip 0 or more options (starting with -),
      # then treat word starting with lowercase letter as remote name
      if [[ "$target" =~ git\ push(\ +-[a-zA-Z0-9]+)*(\ +)([a-z][a-z0-9_-]*) ]]; then
        # Remote name extracted (BASH_REMATCH[3])
        remote="${BASH_REMATCH[3]}"
        if [[ "$remote" != "origin" ]]; then
          echo "{\"decision\": \"block\", \"reason\": \"git push to remotes other than origin is prohibited\"}"
          exit 0
        fi
      fi
    fi
  fi

  # Block git clone with external URL (allow only local paths)
  if [[ "$target" == *"git clone"* ]]; then
    # Block if contains protocols like http://, https://, git@, ssh://
    if [[ "$target" =~ git[[:space:]]+clone[[:space:]]+(https?://|git@|ssh://) ]]; then
      echo "{\"decision\": \"block\", \"reason\": \"git clone from external repositories is prohibited\"}"
      exit 0
    fi
  fi

  # Allow git command range operators (.. and ...)
  # These are different from parent directory file paths, so handle specially
  if [[ "$target" == *"git "* ]]; then
    # For git commands, skip parent directory check below
    # (.. might be used as range operator)
    :  # Do nothing (proceed to next check)
  else
    # For non-git commands, check parent directory access
    if [[ "$target" == *"../"* ]] || [[ "$target" == *".."* ]]; then
      echo "{\"decision\": \"block\", \"reason\": \"Access to parent directory is prohibited\"}"
      exit 0
    fi
  fi
else
  # For non-Bash tools (Read/Edit/Write), perform normal parent directory check
  if [[ "$target" == *"../"* ]] || [[ "$target" == *".."* ]]; then
    echo "{\"decision\": \"block\", \"reason\": \"Access to parent directory is prohibited\"}"
    exit 0
  fi
fi

# Prohibited pattern checks
# 1. Access to home directory (~)
if [[ "$target" == ~* ]] || [[ "$target" == *"~/"* ]]; then
  echo "{\"decision\": \"block\", \"reason\": \"Access to home directory is prohibited\"}"
  exit 0
fi

# 2. For absolute paths, block access outside working directory
if [[ "$target" == /* ]] && [[ "$target" != "$WORK_DIR"* ]] && [[ "$target" != "/tmp/claude"* ]] && [[ "$target" != "/dev/"* ]]; then
  echo "{\"decision\": \"block\", \"reason\": \"Access outside working directory is prohibited: $target\"}"
  exit 0
fi

# Allow
exit 0
