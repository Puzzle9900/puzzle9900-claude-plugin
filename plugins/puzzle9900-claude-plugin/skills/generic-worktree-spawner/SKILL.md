---
name: generic-worktree-spawner
description: Opens a new Claude session in a git worktree. Creates the worktree if it does not exist, re-enters it if it does. Accepts a worktree name and an optional initial prompt. Fully generic — no knowledge of Jira, tickets, or workflows.
---

# generic-worktree-spawner

## Overview

Opens a new iTerm tab with a Claude session in the specified worktree. If the worktree already exists it re-enters it; if not, `claude --worktree` creates it. An optional prompt is passed to Claude as the first message when the session opens.

`open-claude-tab.sh` (sibling of this SKILL.md) handles all shell logic — this skill only resolves the repo root and calls the script with the correct flags.

## Inputs

| Input | Required | Description |
|---|---|---|
| `worktree-name` | Yes | The worktree name (e.g. `story/MOB-1234/add-dark-mode`) |
| `prompt` | No | Initial message to send to Claude when the session opens. Omit for an empty interactive session. |
| `repo` | No | Absolute path to the git repo root. If not provided, resolved via `git rev-parse --show-toplevel` from the current directory. |

## Steps

### 1. Resolve repo root

If `repo` was not provided:
```bash
git rev-parse --show-toplevel
```
Store as `{REPO_ROOT}`.

### 2. Call open-claude-tab.sh

`open-claude-tab.sh` lives in the same folder as this SKILL.md. Call it as a sibling:

**With prompt:**
```bash
bash <path-to-this-skill>/open-claude-tab.sh \
  -t "{worktree-name}" \
  -r "{REPO_ROOT}" \
  -w "{worktree-name}" \
  -m "{prompt}" \
  -p
```

**Without prompt** (omit `-m`):
```bash
bash <path-to-this-skill>/open-claude-tab.sh \
  -t "{worktree-name}" \
  -r "{REPO_ROOT}" \
  -w "{worktree-name}" \
  -p
```

### 3. Confirm and stop

Show:
> "Session opening in worktree `{worktree-name}`."

This skill is done. All further work happens in the new session.

## Constraints

- Never write shell code inline — all shell logic lives in `open-claude-tab.sh`
- Never call `git worktree add` or `EnterWorktree` — the script handles worktree creation
- Never change the current session's CWD
- `-p` (`--dangerously-skip-permissions`) is always passed — required for unattended skill execution in the new session
