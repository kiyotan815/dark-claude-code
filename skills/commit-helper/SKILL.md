---
name: commit-helper
description: Create Git commits with multi-line commit messages in sandbox mode. Uses temporary files to work around HEREDOC limitations.
---

# Creating Multi-line Commit Messages

Create Git commits with properly formatted multi-line commit messages.

## When to Use This Skill

Use this when you need to create commits with detailed multi-line messages including:
- Clear and concise subject line
- Additional context or explanation in the body
- References to issues or related work
- Co-author attribution

## How It Works

To work around HEREDOC limitations in sandbox mode, create a temporary file in `/tmp/claude/`.

## Instructions

Follow these steps to create a commit:

### 1. Check Changes

First, check what changes will be committed with git status:

```bash
git status
```

Check change details with git diff:

```bash
git diff
```

### 2. Stage Files

If not already staged, stage the files:

```bash
git add <files>
```

### 3. Create Commit Message File

Use the Write tool to create a commit message file at `/tmp/claude/commit-message.txt`

**Format**:

```
Subject line (50 characters or less)

More detailed explanatory text if necessary. Wrap at about 72
characters. The blank line separating the subject from the body
is critical.

- Bullet points are okay
- Use hyphens or asterisks
```

### 4. Execute Commit

Execute commit using the temporary file, then delete it:

```bash
git commit -F /tmp/claude/commit-message.txt && rm /tmp/claude/commit-message.txt
```

### 5. Verify Commit

Verify the commit was created successfully:

```bash
git log -1 --format='%h %s'
```

Or for details:

```bash
git log -1
```

## Important Notes

- Always create temporary files in `/tmp/claude/` (writable in sandbox)
- Always delete temporary files after use (`&& rm /tmp/claude/commit-message.txt`)
- Use the `-F` option (uppercase F) to specify file containing commit message
- `-f` option has a different meaning, be careful
- Follow project commit message conventions

## Examples

### Basic Usage

```bash
# 1. Check changes
git status
git diff

# 2. Stage files
git add src/main.py README.md

# 3. Create commit message with Write tool (/tmp/claude/commit-message.txt)
# Content:
# """
# Add user authentication feature
#
# - Implement JWT token-based authentication
# - Add login/logout API endpoints
# - Improve session management
# """

# 4. Execute commit and delete temporary file
git commit -F /tmp/claude/commit-message.txt && rm /tmp/claude/commit-message.txt

# 5. Verify
git log -1 --format='%h %s'
```

### Bug Fix Example

```bash
# Create commit message with Write tool (/tmp/claude/commit-message.txt)
# Content:
# """
# Fix error handling during login
#
# Fixed issue where server crashed when invalid credentials
# were submitted.
#
# Fixes #123
# """

git commit -F /tmp/claude/commit-message.txt && rm /tmp/claude/commit-message.txt
```
