---
name: pr-helper
description: Create GitHub pull requests with multi-line descriptions in sandbox mode. Uses temporary files to work around HEREDOC limitations.
---

# Creating Pull Requests with Multi-line Descriptions

Create GitHub pull requests with properly formatted multi-line descriptions.

## When to Use This Skill

Use this when you need to create pull requests with detailed descriptions including:
- Summary of changes
- Background and rationale
- Test instructions
- References to related issues
- Screenshots or code examples

## How It Works

To work around HEREDOC limitations in sandbox mode, create a temporary file in `/tmp/claude/`.

## Instructions

Follow these steps to create a pull request:

### 1. Check Current Branch and Changes

Check current branch with git status:

```bash
git status
```

Check commit history with git log:

```bash
git log origin/main..HEAD --oneline
```

### 2. Check Diff

Check diff against main branch:

```bash
git diff origin/main...HEAD
```

### 3. Push to Remote

If not already pushed, push to remote (run with dangerouslyDisableSandbox: true):

```bash
git push -u origin <branch-name>
```

**Note**: git push requires connection to remote repository, so `dangerouslyDisableSandbox: true` must be specified. This parameter is per-command and doesn't affect subsequent commands.

### 4. Create Pull Request Description File

Use the Write tool to create a PR description at `/tmp/claude/pr-body.txt`

**Recommended Format**:

```markdown
## Summary

Briefly explain the purpose of this PR in 1-2 sentences.

## Changes

- Description of change 1
- Description of change 2
- Description of change 3

## Background

Explain why this change is necessary.

## Test Instructions

1. Step 1
2. Step 2
3. Expected result

## Related Issues

Closes #123

## Screenshots (if applicable)

![Description](image-url)
```

### 5. Create Pull Request

Use GitHub CLI (gh) to create PR:

Create PR using temporary file, then delete it:

```bash
gh pr create --title "PR Title" --body-file /tmp/claude/pr-body.txt && rm /tmp/claude/pr-body.txt
```

To specify base branch:

```bash
gh pr create --title "PR Title" --base main --body-file /tmp/claude/pr-body.txt && rm /tmp/claude/pr-body.txt
```

**Note**: gh command also requires connection to remote repository, so `dangerouslyDisableSandbox: true` must be specified.

### 6. Verify Pull Request

Verify PR was created successfully:

```bash
gh pr view --web
```

Or:

```bash
gh pr view
```

## Important Notes

- Always create temporary files in `/tmp/claude/` (writable in sandbox)
- Always delete temporary files after use (`&& rm /tmp/claude/pr-body.txt`)
- Use `--body-file` option to read body from file
- Specify PR title with `--title` option
- Follow project PR template if one exists

## Examples

### Basic Usage

```bash
# 1. Check branch and changes
git status
git log origin/main..HEAD --oneline
git diff origin/main...HEAD

# 2. Push to remote (dangerouslyDisableSandbox: true)
git push -u origin feature/user-auth

# 3. Create PR description with Write tool (/tmp/claude/pr-body.txt)
# Content:
# """
# ## Summary
#
# Implement user authentication feature.
#
# ## Changes
#
# - Implement JWT token-based authentication
# - Add login/logout API endpoints
# - Improve session management
#
# ## Test Instructions
#
# 1. Start the application
# 2. Send POST request to `/api/login`
# 3. Verify token is returned
# """

# 4. Create PR and delete temporary file (dangerouslyDisableSandbox: true)
gh pr create --title "Add user authentication feature" --base main --body-file /tmp/claude/pr-body.txt && rm /tmp/claude/pr-body.txt

# 5. Verify
gh pr view --web
```

### Bug Fix Example

```bash
# 1. Check branch and changes
git status
git log origin/main..HEAD --oneline

# 2. Push to remote (dangerouslyDisableSandbox: true)
git push -u origin fix/login-error

# 3. Create PR description with Write tool (/tmp/claude/pr-body.txt)
# Content:
# """
# ## Summary
#
# Fix error handling during login.
#
# ## Changes
#
# - Add validation for invalid credentials
# - Standardize error response format
# - Return appropriate HTTP status codes
#
# ## Background
#
# Fixed issue where server crashed when invalid credentials
# were submitted.
#
# ## Related Issues
#
# Fixes #123
# """

# 4. Create PR and delete temporary file (dangerouslyDisableSandbox: true)
gh pr create --title "Fix error handling during login" --body-file /tmp/claude/pr-body.txt && rm /tmp/claude/pr-body.txt

# 5. Verify
gh pr view
```
