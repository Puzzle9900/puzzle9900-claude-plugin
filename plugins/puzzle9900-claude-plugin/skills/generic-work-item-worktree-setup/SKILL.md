---
name: generic-work-item-worktree-setup
description: Use when you need to create a feature branch worktree, write the workflow state file, and launch a new Claude session inside the worktree for any work item — a Jira ticket, a plain description, a spec path, or any topic you want to work on. Runs in the main repo session and hands off completely to the new session — no further work happens here.
---

# generic-work-item-worktree-setup

## Overview

Creates the feature branch worktree at `.worktrees/{name}/`, writes the initial `.workflow` state file inside it, and opens a new iTerm tab pointed at the worktree with a Claude session pre-loaded to run the full implementation workflow.

This skill runs entirely in the **main repo session**. It does not switch CWD, does not run any phases itself, and does not use `EnterWorktree`. Once the new iTerm tab is open, this skill is done — all subsequent work happens in the new session.

## When to Use

- "Create the worktree for PROJ-123 and launch the workflow"
- "Set up and start PROJ-123"
- After `generic-work-item-preparation` completes (intention is clean, Jira is updated)
- As the entry point when running the full workflow from scratch

**Not this skill:** if the worktree already exists and you want to run a specific phase — invoke that phase skill directly inside the worktree session.

## Steps

### 1. Resolve ticket metadata

Parse the argument for a Jira ticket key (e.g. `PROJ-123`) or URL.

If no key is provided, ask: "Which ticket should I create the worktree for?"

Fetch the ticket via Atlassian MCP:
```
getJiraIssue(key) → extract: issuetype.name, key, summary
```

If Atlassian MCP is unavailable, ask:
> "I can't reach Jira. Please provide: issue type (Story / Bug / Task / Feature) and a short summary."

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

**Summary slug:** lowercase the summary, replace spaces with dashes, strip every character not in `[a-z0-9-]`.

**Length check:** if the full name exceeds 64 characters, truncate the summary slug to fit. Never truncate the type or key segments.

Example:
- Key: `MOB-1234`, type: Story, summary: "Add dark mode to Settings screen"
- Name: `story/MOB-1234/add-dark-mode-to-settings-screen`

### 3. Detect the repo root

```bash
git rev-parse --show-toplevel
```

Store as `REPO_ROOT`. All subsequent paths are absolute and derived from this.

### 4. Detect run mode

If the user's invocation message contains "autonomous", "fully autonomous", or "no human input" → set `MODE = "autonomous"` without asking.

Otherwise use the AskUserQuestion tool with the following options for the user to select from:

- question: `Choose a run mode for this workflow:`
- options:
  - `autonomous — no stops; Claude makes all decisions with its best judgment`
  - `auto — stops only for genuine decisions (feature lists, spec approval, impact queue)`
  - `pause — stops between every phase`

Default to `auto` if the user dismisses without selecting.

### 5. Create the worktree

```bash
mkdir -p "$REPO_ROOT/.worktrees"
git -C "$REPO_ROOT" worktree add ".worktrees/{name}" -b "{name}"
```

The worktree lives at `{REPO_ROOT}/.worktrees/{name}/` — never inside `.claude/`.

Ensure `.worktrees/` is gitignored:
```bash
grep -qxF '.worktrees/' "$REPO_ROOT/.gitignore" 2>/dev/null \
  || echo '.worktrees/' >> "$REPO_ROOT/.gitignore"
```

### 6. Write the .workflow state file

```bash
mkdir -p "$REPO_ROOT/.worktrees/{name}/.claude"
```

Use the **Write tool** to create `{REPO_ROOT}/.worktrees/{name}/.claude/.workflow`:

```json
{
  "ticket": "{KEY}",
  "repo": "{REPO_ROOT}",
  "work_dir": "{REPO_ROOT}/.worktrees/{name}",
  "worktree": "{name}",
  "branch": "{name}",
  "mode": "{MODE}",
  "slack_notify_channel": null,
  "session_id": "unknown",
  "current_phase": 1,
  "completed_phases": [],
  "created_at": "{ISO8601_NOW}",
  "updated": "{ISO8601_NOW}"
}
```

`slack_notify_channel`: read from the project's `CLAUDE.md` (look for `SLACK_NOTIFY_CHANNEL: {value}`); use `null` if not found.

### 7. Open new iTerm tab

Do **not** pass arguments to `open-claude-tab.sh` from the Bash tool — argument quoting is unreliable when Claude constructs the call. Instead, write the `.command` file content directly using the **Write tool**, then open it.

**Step 7a — write the launch file**

Use the Write tool to create a launch file at `{REPO_ROOT}/.worktrees/{name}/.claude/launch.command` with this exact content (substitute all values before writing):

```bash
#!/bin/zsh -l
cd "{REPO_ROOT}/.worktrees/{name}"
claude --name "{name}" -p "/generic-work-item-full-implementation-workflow {work_item}"
```

Where:
- `{name}` — the worktree name derived in Step 2 (e.g. `story/MOB-1234/add-dark-mode`)
- `{REPO_ROOT}` — the absolute repo root resolved in Step 3
- `{work_item}` — whatever was provided when invoking this skill (Jira key, description, spec path, etc.)

**Do not include `--worktree`** in the claude invocation. The `cd` already places the session in the correct git worktree — Claude detects the context from CWD. Passing `--worktree` with a name that was registered via `git worktree add` (not `EnterWorktree`) causes Claude to fail silently and exit.

**Step 7b — make it executable and open it**

```bash
chmod +x "{REPO_ROOT}/.worktrees/{name}/.claude/launch.command"
open -a iTerm "{REPO_ROOT}/.worktrees/{name}/.claude/launch.command"
```

The `#!/bin/zsh -l` shebang opens a login shell, loading the full user PATH including `claude`. The file self-contained — no argument parsing, no quoting issues.

**The worktree directory must exist before this step runs.** Step 5 creates it.

### 8. Confirm

Show:
> "Worktree created at `.worktrees/{name}/`. New iTerm tab launched — Claude is starting the full workflow for **{KEY}**."

This skill is now done. All further work happens in the new session.

## Constraints

- Never call `EnterWorktree` — always use `git worktree add` directly
- Never switch CWD in the current session — this skill runs entirely in the main repo context
- Worktrees must live at `{REPO_ROOT}/.worktrees/{name}/` — never inside `.claude/`
- Always ensure `.worktrees/` is gitignored before creating the worktree
- The `.workflow` file must be written before the iTerm tab is opened — the new session reads it on startup
- `work_dir` in `.workflow` must be the absolute path to the worktree root
- If Atlassian MCP is unavailable, fall back to manual user input — do not block on Jira availability
- Always use `open-claude-tab.sh` for opening iTerm — it lives in the same folder as this SKILL.md file
