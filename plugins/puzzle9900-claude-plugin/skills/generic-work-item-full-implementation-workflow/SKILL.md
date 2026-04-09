---
name: generic-work-item-full-implementation-workflow
description: Use when you want to take a work item all the way from raw idea or incomplete ticket to fully implemented code and a draft PR in a single end-to-end workflow. Runs preparation → technical scope → implementation → ship in sequence, gating at each transition. Do not use if you only need one phase — invoke the individual skill instead.
---

# generic-work-item-full-implementation-workflow

## Overview

Chains five skills — `generic-work-item-preparation`, `generic-work-item-pre-implementation-tech-scope`, `generic-work-item-implementation-start`, and `generic-work-item-ship` — taking a work item from raw idea or incomplete ticket all the way to a reviewed draft PR.

This skill always runs inside a worktree session. The worktree is created and this session is launched by `generic-work-item-worktree-setup` running in the main repo. On startup, this skill reads `.claude/.workflow` to load the ticket, mode, and resume state — that file is always present when this skill runs.

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

`.claude/.workflow` is always present when this skill starts — written by `generic-work-item-worktree-setup` before this session was opened. All reads and writes go through `generic-work-item-workflow-state`.

`work_dir` = the current working directory (`pwd`) — this session IS the worktree, so no derivation is needed.

## Steps

### 0. Load state

Invoke `generic-work-item-workflow-state` with `operation: read`.

The state file is always present. If it is missing, stop and tell the user:
> "No `.claude/.workflow` found. This skill must be launched via `generic-work-item-worktree-setup` from the main repo session, or run from inside an existing worktree that already has a state file."

From state, load: `ticket`, `work_dir`, `mode`, `current_phase`, `completed_phases`.

Show startup banner:
> "**{TICKET}** — {mode} mode. Starting from Phase {current_phase}. Completed: {completed_phases}."

Transition ticket to In Progress (see below), then proceed immediately to the step for `current_phase`.

**Ticket transition:**
1. `getTransitionsForJiraIssue(key)`
2. If status is Draft or Ready → call `transitionJiraIssue(key, transitionId)` for In Progress
3. If already In Progress or later → skip
4. If Atlassian MCP unavailable → skip silently

### 1. Phase 1 — Preparation (conditional)

Skip if `completed_phases` contains `1`.

Invoke `generic-work-item-workflow-state` with `operation: update, current_phase: 1`.

Invoke `generic-work-item-preparation` with `ticket` and `work_dir`.

Invoke `generic-work-item-workflow-state` with `operation: update, completed_phases: [..., 1], current_phase: 2` immediately after the skill returns.

**autonomous/auto:** show "**Phase 1 complete** — Jira updated. → Starting Phase 2..." and proceed without stopping.
**pause:** ask "Ready to start the technical scope? (yes / stop here)". If stopped: "To resume: run `/generic-work-item-full-implementation-workflow {TICKET}` in this session."

### 2. Phase 2 — Technical Scope (conditional)

Skip if `completed_phases` contains `2`.

Invoke `generic-work-item-workflow-state` with `operation: update, current_phase: 2`.

Invoke `generic-work-item-pre-implementation-tech-scope` with `ticket` and `work_dir`.

Invoke `generic-work-item-workflow-state` with `operation: update, completed_phases: [..., 2], current_phase: 3` immediately after the skill returns.

**autonomous/auto:** show "**Phase 2 complete** — `technical-scope.md` saved. → Starting Phase 3..." and proceed.
**pause:** ask "Ready to start implementation? (yes / stop here)".

### 3. Phase 3 — Implementation (conditional)

Skip if `completed_phases` contains `3`.

Invoke `generic-work-item-workflow-state` with `operation: update, current_phase: 3`.

Invoke `generic-work-item-implementation-start` with `ticket` and `work_dir`.

Invoke `generic-work-item-workflow-state` with `operation: update, completed_phases: [..., 3], current_phase: 4` immediately after the skill returns.

**autonomous/auto:** show "**Phase 3 complete** — Implementation reviewed. → Starting Phase 4..." and proceed.
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
- All state file operations go through `generic-work-item-workflow-state` — never raw Read or Write tool calls on `.claude/.workflow`
- Invoke `generic-work-item-workflow-state` twice per phase: once before (`current_phase`), once after (`completed_phases`) — never defer these to a subsequent turn
- If a skill fails or the user stops mid-phase, do not advance `completed_phases` — the phase must be retried in full
- State file tracks phases only — not sub-steps or area-level tracking
- All file writes by sub-skills go to `work_dir` — never to the main repo or any absolute path outside the worktree
