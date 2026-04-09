---
name: generic-work-item-full-implementation-workflow
description: Use when you want to take a work item all the way from raw idea or incomplete ticket to fully implemented code and a draft PR in a single end-to-end workflow. Runs preparation → technical scope → implementation → ship in sequence, gating at each transition. Do not use if you only need one phase — invoke the individual skill instead.
---

# generic-work-item-full-implementation-workflow

## Overview

Chains five skills — `generic-work-item-preparation`, `generic-work-item-pre-implementation-tech-scope`, `generic-work-item-implementation-start`, and `generic-work-item-ship` — taking a work item from raw idea or incomplete ticket all the way to a reviewed draft PR.

This skill always runs inside a worktree session. The worktree is created and this session is launched by `generic-work-item-worktree-setup` running in the main repo. On startup, this skill reads `.workflow` to load the ticket, mode, and resume state — that file is always present when this skill runs.

This skill owns sequencing, state management, and transition gates only. Each phase is fully delegated to its individual skill.

## When to Use

This skill is invoked automatically by `generic-work-item-worktree-setup` via:
```
claude --worktree {name} -p "/generic-work-item-full-implementation-workflow {TICKET}"
```

It can also be invoked manually inside a worktree session:
- "Run the full workflow for PROJ-123"
- "Continue the workflow for PROJ-123" (resumes from last completed phase)

**Not this skill:** if you only need one phase, invoke that skill directly.

## State File

`.workflow` is created by this skill on first run inside the worktree session. All reads and writes go through `generic-work-item-workflow-state`.

`work_dir` = `pwd` at session start — this session IS the worktree.

## Steps

### 0. Initialize or resume

Run:
```bash
pwd
```
Store as `work_dir`.

Invoke `generic-work-item-workflow-state` with `operation: read`.

**Path A — state file exists (resuming):**

Load: `ticket`, `work_dir`, `mode`, `current_phase`, `completed_phases`.

Show:
> "Resuming **{ticket}** — {mode} mode. Phase {current_phase}. Completed: {completed_phases}."

Proceed to the step for `current_phase`.

**Path B — no state file (fresh start):**

Ask for run mode using the AskUserQuestion tool with options for the user to select from:
- question: `Choose a run mode for this workflow:`
- options:
  - `autonomous — no stops; Claude makes all decisions with its best judgment`
  - `auto — stops only for genuine decisions (feature lists, spec approval, impact queue)`
  - `pause — stops between every phase`

Default to `auto` if dismissed without selecting. Store as `mode`.

Read `SLACK_NOTIFY_CHANNEL` from `CLAUDE.md` if present (`SLACK_NOTIFY_CHANNEL: {value}`), else `null`.

Invoke `generic-work-item-workflow-state` with `operation: create` and all values: `ticket` (from `-p` argument), `repo` (from `git rev-parse --show-toplevel`), `work_dir`, `worktree` (from `git rev-parse --show-prefix`), `branch` (from `git branch --show-current`), `mode`, `slack_notify_channel`.

Show startup banner:
> "**{ticket}** — {mode} mode. Starting Phase 1."

**Ticket transition (both paths):**
1. `getTransitionsForJiraIssue(key)`
2. If status is Draft or Ready → `transitionJiraIssue(key, transitionId)` to In Progress
3. If already In Progress or later → skip
4. If Atlassian MCP unavailable → skip silently

### 1. Phase 1 — Preparation (conditional)

Skip if `completed_phases` contains `1`.

Invoke `generic-work-item-workflow-state` with `operation: update, current_phase: 1`.

**autonomous/auto:** output exactly this line before invoking the sub-skill:
> "**[Phase 1/4]** Running preparation — will proceed to Phase 2 automatically."

Invoke `generic-work-item-preparation` with `ticket` and `work_dir`.

Invoke `generic-work-item-workflow-state` with `operation: update, completed_phases: [..., 1], current_phase: 2` immediately after the skill returns.

**autonomous/auto:** output exactly this line, then immediately invoke Phase 2 in the same response turn — do not stop:
> "**Phase 1 complete.** → Phase 2 starting now."

**pause:** ask "Ready to start the technical scope? (yes / stop here)". If stopped: "To resume: run `/generic-work-item-full-implementation-workflow {TICKET}` in this session."

### 2. Phase 2 — Technical Scope (conditional)

Skip if `completed_phases` contains `2`.

Invoke `generic-work-item-workflow-state` with `operation: update, current_phase: 2`.

**autonomous/auto:** output exactly this line before invoking the sub-skill:
> "**[Phase 2/4]** Running technical scope — will proceed to Phase 3 automatically."

Invoke `generic-work-item-pre-implementation-tech-scope` with `ticket` and `work_dir`.

Invoke `generic-work-item-workflow-state` with `operation: update, completed_phases: [..., 2], current_phase: 3` immediately after the skill returns.

**autonomous/auto:** output exactly this line, then immediately invoke Phase 3 in the same response turn — do not stop:
> "**Phase 2 complete.** → Phase 3 starting now."

**pause:** ask "Ready to start implementation? (yes / stop here)".

### 3. Phase 3 — Implementation (conditional)

Skip if `completed_phases` contains `3`.

Invoke `generic-work-item-workflow-state` with `operation: update, current_phase: 3`.

**autonomous/auto:** output exactly this line before invoking the sub-skill:
> "**[Phase 3/4]** Running implementation — will proceed to Phase 4 automatically."

Invoke `generic-work-item-implementation-start` with `ticket` and `work_dir`.

Invoke `generic-work-item-workflow-state` with `operation: update, completed_phases: [..., 3], current_phase: 4` immediately after the skill returns.

**autonomous/auto:** output exactly this line, then immediately invoke Phase 4 in the same response turn — do not stop:
> "**Phase 3 complete.** → Phase 4 starting now."

**pause:** ask "Ready to commit and open a draft PR? (yes / stop here)".

### 4. Phase 4 — Ship

Invoke `generic-work-item-workflow-state` with `operation: update, current_phase: 4`.

Invoke `generic-work-item-ship` with `ticket` and `work_dir`.

Invoke `generic-work-item-workflow-state` with `operation: update, completed_phases: [..., 4], current_phase: 5` immediately after the skill returns.

Present the PR URL as the final output.

## Resuming after context compression

Claude Code compresses context when it grows large. After compression, in-flight state is lost and Claude stops. When the user types anything (e.g. "continue"):

1. Invoke `generic-work-item-workflow-state` with `operation: read`
2. If state found and `current_phase < 5` → show "Resuming **{TICKET}** from Phase {current_phase}." and immediately invoke that phase — do not re-ask about mode or ticket
3. If state not found → ask the user which ticket to run

In autonomous mode, after each phase completes, invoke the next phase in the same response turn — never wait for user input between phases. Context compression is the only expected interruption.

## Constraints

- This skill runs inside a worktree session — never call `EnterWorktree` or switch CWD
- `work_dir` = `pwd` at session start — read from `.workflow`, no derivation needed
- Do not end your response turn between phase transitions in autonomous mode — write `.workflow`, show one-line status, invoke next phase without stopping
- This skill only orchestrates — it never writes code, reads the codebase, modifies Jira, or creates spec files directly
- Each phase is fully delegated to its skill; do not replicate their internal logic here
- All state file operations go through `generic-work-item-workflow-state` — never raw Read or Write tool calls on `.workflow`
- Invoke `generic-work-item-workflow-state` twice per phase: once before (`current_phase`), once after (`completed_phases`) — never defer these to a subsequent turn
- If a skill fails or the user stops mid-phase, do not advance `completed_phases` — the phase must be retried in full
- State file tracks phases only — not sub-steps or area-level tracking
- All file writes by sub-skills go to `work_dir` — never to the main repo or any absolute path outside the worktree
