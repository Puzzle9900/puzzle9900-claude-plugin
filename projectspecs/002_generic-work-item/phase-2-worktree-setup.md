# Generic Work Item Worktree Setup

**Milestone**: 002_generic-work-item-worktree-setup
**Created**: 2026-04-08
**Status**: Draft

## Overview

Creates the feature branch worktree at `.worktrees/{name}/` inside the repository, writes the initial `.workflow` state file into `.worktrees/{name}/.claude/.workflow`, and opens a new iTerm tab with a Claude session launched natively inside the worktree.

This skill runs entirely in the **main repo session** and hands off completely once the new iTerm tab is open. It never calls `EnterWorktree` and never switches the current session's CWD. The new Claude session — launched via `claude --worktree {name}` — is fully independent, with the worktree as its native project root.

**Why not inside `.claude/worktrees/`?** Placing worktrees outside `.claude/` prevents Claude Code from inheriting the main project's hooks and settings via directory traversal. The new session starts clean with no relative-path issues.

**As a standalone skill:** can be run independently to set up a worktree for a ticket without the full workflow.

This skill is the second step in the work item pipeline:

```
generic-work-item-preparation
  → (clean intention, Jira updated)
generic-work-item-worktree-setup   ← this milestone
  → (worktree created, CWD = feature branch)
generic-work-item-pre-implementation-tech-scope
  → (technical scope: areas, contracts, checklist)
generic-work-item-implementation-start
  → (implemented solution, reviewed and verified)
generic-work-item-ship
  → (draft PR, approved)
```

---

## Workflow

```
User invokes skill with ticket key
        │
        ▼
Step 0: Load ticket metadata
  ├─ Jira ticket key → fetch via Atlassian MCP
  └─ Extract: issue type, ticket key, summary
        │
        ▼
Step 1: Derive worktree name
  type  = issue type → type slug (see mapping below)
  key   = ticket key as-is (e.g. MOB-1234)
  slug  = summary → lowercase · spaces→dashes · strip non-[a-z0-9-]
  name  = {type}/{key}/{slug}
  if len(name) > 64: truncate slug to fit (preserve type and key segments)
        │
        ▼
Step 2: Detect repo root and run mode
  REPO_ROOT = git rev-parse --show-toplevel
  Ask user for mode (autonomous / auto / pause) — or infer from invocation message
        │
        ▼
Step 3: Create worktree
  git -C "$REPO_ROOT" worktree add ".worktrees/{name}" -b "{name}"
  → .worktrees/{name}/ created at repo root (NOT inside .claude/)
  → ensure .worktrees/ is in .gitignore
  → session CWD does NOT change
        │
        ▼
Step 4: Write .workflow state file
  mkdir -p "$REPO_ROOT/.worktrees/{name}/.claude"
  Write: $REPO_ROOT/.worktrees/{name}/.claude/.workflow
  Fields: ticket, repo, work_dir, worktree, branch, mode,
          slack_notify_channel, session_id, current_phase=1,
          completed_phases=[], created_at, updated
        │
        ▼
Step 5: Open new iTerm tab
  osascript → iTerm2 new tab running:
    claude --worktree "{name}" -p "/generic-work-item-full-implementation-workflow {KEY}"
        │
        ▼
Step 6: Confirm and stop
  "Worktree created at .worktrees/{name}/. New iTerm tab launched."
  This skill is done — all further work happens in the new session.
```

---

## Goals

- Establish the feature branch worktree before any local files are written
- Ensure the new Claude session starts natively inside the worktree with no inherited hooks or settings from the main repo
- Hand off completely to the new session — the main session has no further role in the workflow

---

## Worktree Name Convention

```
{type}/{ticket-key}/{summary-kebab}
```

**Type mapping:**

| Issue type | Slug |
|---|---|
| Story | `story` |
| Bug | `bugfix` |
| Task, Chore | `chore` |
| Feature | `feature` |
| Sub-task | `task` |
| Other | `task` |

**Rules:**
- Each `/`-separated segment: letters, digits, dots, underscores, dashes only
- Total length: max 64 characters
- If total exceeds 64 chars: truncate the summary slug to fit (never truncate type or key)
- Summary slug: lowercase, spaces → dashes, strip all characters not in `[a-z0-9-]`

**Example:**
- Ticket: `MOB-1234`, type: Story, summary: "Add dark mode to Settings screen"
- Worktree path: `.worktrees/story/MOB-1234/add-dark-mode-to-settings-screen`
- Branch: `story/MOB-1234/add-dark-mode-to-settings-screen`

---

## Requirements

### Functional Requirements

- [ ] Accept a Jira ticket key as input; fall back gracefully if Atlassian MCP is unavailable (ask user for type and summary manually)
- [ ] Detect repo root via `git rev-parse --show-toplevel`
- [ ] Derive a valid worktree name following the convention above
- [ ] Truncate the summary slug if the full name exceeds 64 characters
- [ ] Run `git worktree add .worktrees/{name} -b {name}` — never call `EnterWorktree`
- [ ] Ensure `.worktrees/` is in `.gitignore`
- [ ] Write `.workflow` state file to `.worktrees/{name}/.claude/.workflow` before opening iTerm
- [ ] Open a new iTerm tab running `claude --worktree {name} -p "/generic-work-item-full-implementation-workflow {KEY}"`
- [ ] If iTerm2 / osascript unavailable, print the command for the user to run manually
- [ ] Confirm launch to the user and stop — never continue the workflow in the current session

### Non-Functional Requirements

- [ ] Fully generic — no hardcoded repo paths, branch names, or project conventions
- [ ] Name derivation must be deterministic — same ticket always produces the same name
- [ ] The current session's CWD must never change — this skill runs entirely in the main repo context

---

## Tasks

### Specification Phase (this milestone)
- [x] Write phase spec document

### Implementation Phase
- [ ] Create `generic-work-item-worktree-setup` skill
- [ ] Test: worktree created with correct name from a real ticket
- [ ] Test: name truncation when summary slug causes total > 64 chars
- [ ] Test: special characters in ticket summary are stripped correctly
- [ ] Test: Atlassian MCP unavailable — manual fallback path works

---

## Dependencies

- `002_generic-work-item-preparation` — upstream (Phase 1); resolves and enriches the ticket before this skill runs
- Atlassian MCP — used to fetch issue type and summary; degrades gracefully (user provides manually if unavailable)
- `git` CLI — required for `git worktree add`
- iTerm2 + osascript — used to open the new session tab; falls back to printing the command manually if unavailable

---

## Success Criteria

- Given a ticket key, the skill creates `.worktrees/{type}/{key}/{slug}/` without changing the current session's CWD
- `.worktrees/` is gitignored
- `.workflow` is written to `.worktrees/{name}/.claude/.workflow` before the iTerm tab opens
- A new Claude session opens natively in the worktree and starts the full workflow automatically
- The main session stops after confirming launch — it does not continue the workflow

---

## Notes

- The worktree is never cleaned up by this skill — the Ship phase (Phase 5) or the user handles cleanup
- Because the new session starts with `claude --worktree {name}`, it has no inherited hooks or settings from the main repo's `.claude/` directory
