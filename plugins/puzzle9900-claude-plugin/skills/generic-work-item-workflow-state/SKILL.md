---
name: generic-work-item-workflow-state
description: Manages the .workflow state file for generic-work-item-full-implementation-workflow — creates, updates, and reads phase tracking state. File lives at .claude/.workflow inside the worktree so it never needs to be gitignored. Always invoked by the orchestrator, never directly by the user.
---

# generic-work-item-workflow-state

## Overview

Creates and maintains `.claude/.workflow` inside the active worktree. This file is the single source of truth for the full workflow's phase progress. Storing it inside `.claude/` avoids gitignore concerns — that folder is already excluded from version control in most projects, and it is not part of the feature branch working tree.

The file also records the Claude session ID on every write so the last active session is always traceable — useful for recovering context if a session ends unexpectedly.

## File location

```
{worktree-root}/.claude/.workflow
```

## File format

```json
{
  "ticket": "PROJ-1234",
  "repo": "/absolute/path/to/repo",
  "work_dir": "/absolute/path/to/repo/.worktrees/story/PROJ-1234/add-dark-mode",
  "worktree": "story/PROJ-1234/add-dark-mode",
  "branch": "story/PROJ-1234/add-dark-mode",
  "mode": "auto",
  "slack_notify_channel": "D03BTBG3R45",
  "session_id": "<last-session-id>",
  "current_phase": 2,
  "completed_phases": [1],
  "created_at": "2026-04-08T10:00:00Z",
  "updated": "2026-04-08T14:30:00Z"
}
```

`work_dir` is the absolute path to the worktree root, written by `generic-work-item-worktree-setup` before this session opened. It equals `pwd` at the start of the worktree session — this skill never recomputes it.

`session_id` is refreshed on every write with the current Claude session ID.
`slack_notify_channel` is `null` when not configured.

## Operations

Invoke this skill with an `operation` parameter: `create`, `update`, or `read`.

---

### operation: create

Called once during pre-flight when starting a fresh workflow. Creates the `.claude/` directory if needed and writes the initial state file.

**Steps:**

1. Ensure `.claude/` exists at the worktree root:
   ```bash
   mkdir -p .claude
   ```

2. Resolve the session ID:
   ```bash
   # Source 1: env var (available in hook contexts)
   echo $CLAUDE_SESSION_ID
   # Source 2: newest session folder in the worktree's own .claude/sessions/
   ls -t .claude/sessions/ 2>/dev/null | head -1
   ```
   This skill runs inside the worktree session, so `.claude/sessions/` is local to the worktree. On `create` the folder may not exist yet — `"unknown"` is acceptable and will be updated on subsequent writes.
   Store as `SESSION_ID`. If neither source yields a value, use `"unknown"`.

3. Use the **Write tool** to create `.claude/.workflow`:
   ```
   path: .claude/.workflow
   content: full JSON with all fields (see format above)
   ```
   Set `created_at` and `updated` to the current datetime (ISO 8601).

**Required inputs:** `ticket`, `repo`, `work_dir`, `worktree`, `branch`, `mode`, `slack_notify_channel`

`work_dir` is provided by `generic-work-item-worktree-setup` — it is the absolute path to the worktree root and equals `pwd` in the worktree session. This skill does not recompute it.

---

### operation: update

Called before and after each phase invocation. Reads the existing file, merges the provided fields, refreshes `session_id` and `updated`, then writes the result back atomically.

**Steps:**

1. Use the **Read tool** to read `.claude/.workflow`
2. Parse the JSON
3. Merge the provided fields into the parsed object (preserve all existing fields not being updated)
4. Resolve the current session ID (same method as `create` — try `$CLAUDE_SESSION_ID`, then `ls -t .claude/sessions/`) and set `session_id`
5. Set `updated` to the current datetime
6. Use the **Write tool** to write the full merged JSON back to `.claude/.workflow`

**Accepted update fields:** `current_phase`, `completed_phases`, `mode`

---

### operation: read

Called during pre-flight to check for an existing state file and load progress.

**Steps:**

1. Check whether `.claude/.workflow` exists:
   ```bash
   ls .claude/.workflow 2>/dev/null
   ```
2. If found: use the **Read tool** to read and parse it; return the full state object
3. If not found: return `null` — signals a fresh start to the caller

---

## Constraints

- Always use `.claude/.workflow` as the exact path — never the worktree root, never an absolute path
- Always run `mkdir -p .claude` before a `create` — never assume the directory exists
- `update` must always read-then-write — never overwrite fields that are not being updated
- Always refresh `session_id` and `updated` on every `create` and `update` call
- This skill only touches `.claude/.workflow` — it reads and writes no other file
- If the Write tool call fails for any reason, surface the error immediately — do not continue the workflow without a written state file
