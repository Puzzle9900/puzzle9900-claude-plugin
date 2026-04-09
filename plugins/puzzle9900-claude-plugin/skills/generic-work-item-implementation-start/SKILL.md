---
name: generic-work-item-implementation-start
description: Use when a work item already has a completed Technical Scope (produced by generic-work-item-pre-implementation-tech-scope) and is ready to be implemented. Do NOT use if the intention is still unclear, the ticket fields are incomplete, or the Technical Scope section is missing — run the preparation and scoping skills first.
---

# generic-work-item-implementation-start

## Overview

Master orchestrator for the implementation workflow. Takes a completed Technical Scope — produced by `generic-work-item-pre-implementation-tech-scope` — and drives it to a fully implemented solution through a structured five-phase pipeline: impact analysis, foundation build, serial per-area implementation, full solution review, and parallel isolation reviews. All code writing is delegated to sub-agents; this skill owns sequencing, gating, and context propagation.

Each phase is gated: no area starts until the previous area's review is CLEAN, and the full solution review must be CLEAN before isolation reviews begin. The skill never produces test files and never modifies Jira or spec sources.

## When to Use

**Mandatory precondition:** the work item must have a completed `## Technical Scope` section — produced by `generic-work-item-pre-implementation-tech-scope`. This skill will not proceed without it.

Use this skill when:
- The intention is fully defined (problem, outcome, acceptance criteria are clear)
- The Technical Scope exists (areas of impact, data contracts, checklist)
- The user says: "Start the implementation for PROJ-123", "Implement this work item", or "Run implementation start for projectspecs/004_name/spec.md"

**Do not use this skill if:**
- The Jira ticket fields are incomplete or the title is unclear → run `generic-work-item-preparation` first
- The intention is vague or the acceptance criteria are missing → run `generic-work-item-preparation` first
- The Technical Scope section does not exist yet → run `generic-work-item-pre-implementation-tech-scope` first

## Mode

Resolve `mode` before the first step, in this order:
1. `mode` parameter passed by the caller (e.g. from `generic-work-item-full-implementation-workflow`)
2. `mode` field in `.workflow` — read with the Read tool if the file exists at the worktree root
3. Default: `auto`

**autonomous** — skip all confirmation gates; proceed end-to-end without stopping
**auto** — stop only at genuine decision gates
**pause** — stop after every step

## Steps

### Step 0: Load context

Parse the user's message for:

| Input type | Detection | Action |
|---|---|---|
| **Jira ticket key** | e.g. `PROJ-123` or Jira URL | Fetch via Atlassian MCP; extract `## Technical Scope` section |
| **Local spec path** | e.g. `projectspecs/004_name/spec.md` | Read file; extract `## Technical Scope` section |
| **Both** | Key and path both present | Load from both and cross-reference |
| **Nothing provided** | No identifiers in message | Ask: "What should I implement? Provide a Jira ticket key, a spec path, or paste the Technical Scope directly." |

If neither source contains a `## Technical Scope` section, warn the user:

> "The Technical Scope is missing. Run `generic-work-item-pre-implementation-tech-scope` first, then retry."

Do not proceed.

**If Atlassian MCP is unavailable:** fall back to the local spec file. If neither is available, ask the user to paste the Technical Scope directly (paste-only mode).

Extract and store:
- Technical Scope (full section)
- Ticket intention + acceptance criteria
- Platform
- Worktree path: resolve via `git rev-parse --show-toplevel` — this is the root all agents must use for any file reads or writes

### Step 1: Impact analysis

Invoke `generic-work-item-impact-analyzer` with:
- Technical Scope (full)
- Ticket intention
- Acceptance criteria
- Platform

Present the returned Implementation Queue and Foundation Artifacts list to the user.

**Gate:** Ask: "Does this implementation order look right? You can reorder areas, merge two areas into one, or exclude any before I proceed."

Wait for explicit confirmation. If the user adjusts the order or set, update the queue and re-present before proceeding.

**Autonomous mode:** skip the gate — use the impact analyzer's default order as-is.

### Step 2: Foundation

Invoke `generic-work-item-foundation-builder` with:
- Technical Scope (full)
- Full Implementation Queue (including the Foundation Artifacts section)
- Platform
- Worktree path (from Step 0) — the agent must use this as the root for all file writes

After it completes, show the Foundation Manifest to the user.

Invoke `generic-work-item-code-reviewer` with:
- Scope: `foundation`
- Files to review: from the Foundation Manifest (Created + Extended sections)
- Technical Scope, Foundation Manifest, Platform

**If Result is ISSUES FOUND:**
1. Show findings to the user
2. Run `generic-work-item-area-implementer` skill in fix mode: pass the area name as `"Foundation"`, pass only the Critical and Major issues as the fix scope
3. Re-invoke `generic-work-item-code-reviewer` (scope: `foundation`)
4. Repeat until CLEAN — if more than 3 loops on the same scope without reaching CLEAN, surface the issue to the user and ask whether to continue, adjust scope, or stop

**If Result is CLEAN:** proceed to Step 3.

### Step 3: Area implementation loop

For each area in the ordered Implementation Queue — **one at a time, never in parallel:**

#### 3a. Discover expert agent

Glob `agents/**/*<area-keyword>*expert*.md` and `agents/**/*<area-keyword>*.md` in the consuming project.
- If a match is found, record its path
- If no match is found, record `"none"`

#### 3b. Implement area

Run `generic-work-item-area-implementer` skill with:
- Area name
- Area scope (Area Impact Block from the Technical Scope)
- Foundation Manifest (full)
- Technical Scope (full)
- Ticket intention + acceptance criteria
- Platform
- Feature expert file path (from 3a, or `"none"`)

Show the returned Implementation Report to the user.

#### 3c. Review area

Invoke `generic-work-item-code-reviewer` with:
- Scope: `area:<name>`
- Files to review: from the Implementation Report for this area
- Technical Scope (area slice), Foundation Manifest, all Implementation Reports so far, Platform

**If Result is ISSUES FOUND:**
1. Show findings to the user
2. Run `generic-work-item-area-implementer` skill to fix the reported issues for this area only
3. Re-invoke `generic-work-item-code-reviewer` (same area scope)
4. Repeat until CLEAN — if more than 3 loops without reaching CLEAN, surface the issue to the user and ask whether to continue, adjust scope, or stop

**If Result is CLEAN:** advance to the next area in the queue.

Do not start the next area until the current area's review is CLEAN.

### Step 4: Full solution review

After all areas are complete:

Invoke `generic-work-item-code-reviewer` with:
- Scope: `full`
- Files to review: aggregate of all file paths from all Implementation Reports + Foundation Manifest
- Technical Scope (full), Foundation Manifest, all Implementation Reports, Platform

**If Result is ISSUES FOUND:**
1. Show findings to the user
2. For each issue cluster, run `generic-work-item-area-implementer` skill targeting the relevant area and files
3. Re-invoke `generic-work-item-code-reviewer` (scope: `full`)
4. Repeat until CLEAN — if more than 3 loops without reaching CLEAN, surface the issue to the user and ask whether to continue, adjust scope, or stop

**If Result is CLEAN:** proceed to Step 5.

### Step 5: Isolation reviews

Launch one `generic-work-item-isolation-reviewer` per area, all **in parallel** (they are read-only):

For each area, invoke with:
- Area name
- Area Implementation Report
- Area Impact Block (from Technical Scope)
- Foundation Manifest
- Platform

Collect all isolation findings. Present a summary:

```
## Isolation Review Summary

### Area: <name> — CLEAN / ISSUES FOUND
  Critical: <count>
  Major: <count>
  Top finding: <one-liner or "none">

### Area: <name> — ...
```

**If any Critical isolation findings exist:** route back to Step 4 (full review) for those areas.
**Non-critical findings:** surface to the user as a summary — no further action required.

### Step 6: Done

Present the final implementation summary:

```
## Implementation Complete

### Areas Implemented
- <area name>: <file count> files, <critical issues resolved> critical fixes

### Foundation
- <artifact count> artifacts created/extended

### Review Cycles
- Foundation: <N> review passes
- <Area>: <N> review passes
- Full scope: <N> review passes

### Isolation Findings
- <area>: CLEAN / <N> major findings (non-critical, surfaced above)

### Not Implemented (Out of Scope)
- <anything explicitly excluded>

### Next Steps
- No tests were produced. If test coverage is required, run the appropriate test workflow.
```

## Constraints

- Do not end your response turn between sub-skill invocations — the full loop (area-implementer → code-reviewer → advance) must complete without stopping; only stop when the loop reaches a genuine user gate (>3 review cycles) or all areas are done
- Never launch two area agents concurrently — serial order is mandatory
- Never skip the foundation step, even if the Implementation Queue's Foundation Artifacts section is empty
- Never proceed past a review with unresolved Critical or Major issues
- Do not modify Jira or spec files — this skill does not persist output anywhere; it produces code only
- Do not produce test files at any stage
- The master skill itself does not write any code — all writing is delegated to sub-agents
- Each sub-agent invocation must include full context in its prompt — do not rely on shared state
- If the Atlassian MCP is unavailable, fall back to the local spec file; if neither is available, ask the user to paste the Technical Scope
- If a review loop runs more than 3 times on the same scope without reaching CLEAN, surface the issue to the user and ask whether to continue, adjust scope, or stop

## Boundary Reference

| Allowed — this skill | Not Allowed — out of scope |
|---|---|
| Invoking sub-agents with full context | Writing any code directly |
| Gating phase transitions on CLEAN reviews | Skipping review cycles to save time |
| Routing Critical isolation findings back to full review | Acting on non-critical isolation findings |
| Serial area implementation with one agent at a time | Running two area implementers in parallel |
| Presenting Foundation Manifest and Implementation Reports to the user | Persisting output to Jira or spec files |
| Asking the user to confirm the implementation queue before proceeding | Inferring queue approval from silence |
| Producing test files | — |
