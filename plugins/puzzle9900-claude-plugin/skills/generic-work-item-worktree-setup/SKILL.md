---
name: generic-work-item-worktree-setup
description: Use when you need to create a feature branch worktree and launch a new Claude session inside it for any work item — a Jira ticket, a plain description, a spec path, or any topic you want to work on. Computes the worktree name and opens a new Claude session that creates and enters the worktree. That is its only concern.
---

# generic-work-item-worktree-setup

## Overview

This skill has one responsibility: compute the worktree name and open a new Claude session that creates and enters it.

The worktree is created by `claude --worktree {name}` when the new session opens — not by this skill. Everything that follows (workflow state, mode detection, phases) is handled inside that new session by `generic-work-item-full-implementation-workflow`.

## Steps

### 1. Resolve work item metadata

Parse the argument for a Jira ticket key, URL, or plain description.

If a Jira ticket key or URL is provided, fetch via Atlassian MCP:
```
getJiraIssue(key) → extract: issuetype.name, key, summary
```

If no Jira key is provided or Atlassian MCP is unavailable, ask the user directly for the worktree name they want to use:
> "No Jira ticket found. What would you like to name this worktree? (e.g. `feature/my-feature-name`)"

Use the user's answer as the full `{name}` — skip Step 2 entirely.

### 2. Derive worktree name

Build the name from three `/`-separated segments: `{type}/{key}/{slug}`

**Type mapping:**

| Issue type | Segment |
|---|---|
| Story | `story` |
| Bug | `bugfix` |
| Task, Chore | `chore` |
| Feature | `feature` |
| Sub-task | `task` |
| Any other | `task` |

**Summary slug:** lowercase, spaces → dashes, strip every character not in `[a-z0-9-]`.

**Length:** max 64 characters total — truncate slug to fit, never truncate type or key.

Example: `story/MOB-1234/add-dark-mode-to-settings-screen`

### 3. Spawn the worktree session

Invoke `generic-worktree-spawner` with:
- `worktree-name` = `{name}` (from Step 2)
- `prompt` = `/generic-work-item-full-implementation-workflow {work_item}`

`generic-worktree-spawner` resolves the repo root itself and opens the new Claude session.

### 4. Confirm and stop

Show:
> "Worktree `{name}` is being created — new Claude session opening. The workflow will continue there."

This skill is done. All further work happens in the new session.

## Constraints

- This skill only computes the name and opens the session — nothing else
- This skill only computes the worktree name and invokes `generic-worktree-spawner` — nothing else
- Never call `git worktree add`, `EnterWorktree`, or any shell commands directly
- Never write `.workflow`, `.command` files, or shell code — all of that belongs in `generic-worktree-spawner`
- Never ask about run mode — that happens inside the new session
- Never change the current session's CWD
