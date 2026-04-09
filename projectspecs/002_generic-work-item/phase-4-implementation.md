# Generic Work Item Iron Implementation Start

**Milestone**: 004_generic-work-item-iron-implementation-start
**Created**: 2026-03-27
**Status**: Draft

## Overview

A master orchestration skill that takes a work item with a clean **Technical Scope** (produced by milestone 003) and drives it to a fully-implemented, reviewed solution. It does not skip ahead to writing code — it first builds the zero-impact foundation, then serially expands one implementation agent per area, reviews every increment, and closes with an isolation-scoped final review.

This skill is the fourth step in the work item pipeline:

```
generic-work-item-preparation
  → (clean intention, Jira updated)
generic-work-item-worktree-setup
  → (worktree created, CWD = feature branch)
generic-work-item-pre-implementation-tech-scope
  → (technical scope: areas, contracts, checklist)
generic-work-item-implementation-start   ← this milestone
  → (implemented solution, reviewed and verified)
generic-work-item-ship
  → (draft PR, approved)
```

No tests are produced. The goal is a correct, clean, reviewable implementation — not test coverage.

---

## Workflow

```
User invokes skill with Jira key, spec path, or both
        │
        ▼
Step 0: Load context
  ├─ Jira ticket key → fetch via Atlassian MCP
  ├─ Local spec path → read projectspecs/ file
  ├─ Both → load and cross-reference
  └─ Neither → ask user or accept pasted Technical Scope
        │
        ▼
Step 1: Impact Queue
  agent: generic-work-item-impact-analyzer
  For each area in the Technical Scope, simulate what the
  implementation would touch — files, modules, data boundaries —
  without writing any code. Produces an ordered queue of
  implementation areas with their estimated blast radius and
  dependency order.
        │
        ▼
[Gate] User reviews impact queue — can reorder, exclude, or merge areas
        │
        ▼
Step 2: Zero-Impact Foundation
  agent: generic-work-item-foundation-builder
  Creates the shared backbone: interfaces, data models, connectors,
  and contracts that are required by multiple areas but do not touch
  any existing logic. These artifacts must compile/resolve cleanly
  and cause zero breakage to the existing codebase before any area
  implementation begins.
        │
        ▼
[Review] generic-work-item-code-reviewer (critical + major issues only)
  → if issues found: expand fix sub-agent; repeat review until clean
        │
        ▼
Step 3: Area Identification
  master skill re-reads the foundation artifacts and aligns them
  with the impact queue produced in Step 1. Produces a finalized
  ordered list of independent implementation areas, each referencing
  the relevant foundation artifacts it depends on.
        │
        ▼
Step 4: Serial Area Implementation Loop
  For each area in the ordered list (one at a time, never in parallel):
    ├─ pre-step: search agents/**/*<area>*expert*.md for a local expert
    │     → if found: pass expert agent path + its code paths to implementer
    │     → if not found: pass "none"
    │
    ├─ agent: generic-work-item-area-implementer
    │     Receives: area name, expert agent path, foundation artifacts,
    │               Technical Scope slice for this area, checklist items
    │     Produces: complete implementation of this area using
    │               the foundation contracts
    │               If an expert agent exists, the implementer MUST
    │               leverage it — either by expanding it as a sub-agent
    │               or by deeply consulting its guidance before coding
    │
    └─ [Review] generic-work-item-code-reviewer (critical + major only)
          → if issues found: expand fix sub-agent; repeat review until clean
          → only then advance to the next area
        │
        ▼
Step 5: Full Solution Review
  agent: generic-work-item-code-reviewer (full scope)
  Reviews the entire implementation holistically:
  - Cross-area consistency and contract alignment
  - Regression risks introduced by the combined changes
  - Architectural correctness against the Technical Scope
  - Critical and major issues that only emerge when all areas are combined
  → if issues found: expand targeted fix sub-agent per issue cluster;
    repeat review until clean
        │
        ▼
Step 6: Isolation Scope Reviews
  For each area (in parallel — read-only, no further writes):
    agent: generic-work-item-isolation-reviewer
    Receives: the implementation files for that area only
    Reviews: internal correctness, contract adherence, edge cases,
             and potential failures specific to this isolated scope
    Produces: a findings report (informational — no further fixes
             unless findings are critical)
  → critical findings route back to Step 5 full review
  → non-critical findings are surfaced to the user as a summary
        │
        ▼
Step 7: Done
  master skill presents the implementation summary:
  - Areas implemented
  - Issues found and resolved per review cycle
  - Isolation review findings (if any)
  - What was NOT implemented (explicitly out of scope)
```

---

## Goals

- Drive a Technical Scope to a complete, correct implementation with no skipped steps
- Build zero-impact foundations first so that each area implementation has clean contracts to depend on
- Serialize area implementations to avoid competing writes and cascading breakage
- Leverage existing feature expert agents in the consuming project wherever they exist
- Review every increment — foundation, each area, and the full solution — before advancing
- Close with per-area isolation reviews that catch issues invisible at the integration level

---

## Requirements

### Functional Requirements

- [ ] Accept a Jira ticket key, a local spec path, or both as input; fall back gracefully if only one source is available
- [ ] Accept pasted Technical Scope when no source can be loaded
- [ ] Launch `generic-work-item-impact-analyzer` to simulate area-level blast radius and produce an ordered implementation queue
- [ ] Gate on user confirmation of the impact queue before proceeding (user can reorder, merge, or exclude areas)
- [ ] Launch `generic-work-item-foundation-builder` to create zero-impact shared artifacts before any area is touched
- [ ] After foundation: launch `generic-work-item-code-reviewer` for critical and major issues; loop until clean
- [ ] Produce a finalized ordered area list by aligning the impact queue with the foundation artifacts
- [ ] Implement areas one at a time — never launch two area agents concurrently
- [ ] Before each area: search the consuming project's `agents/` directory for a local expert agent matching the area name
- [ ] Pass the expert agent path (or `"none"`) to each area implementer
- [ ] If an expert agent exists, the area implementer must actively leverage it (expand as sub-agent or deeply consult its guidance)
- [ ] After each area: launch `generic-work-item-code-reviewer`; loop until clean before advancing to the next area
- [ ] After all areas: launch a full-scope `generic-work-item-code-reviewer`; loop until clean
- [ ] After full review: launch one `generic-work-item-isolation-reviewer` per area in parallel (read-only)
- [ ] Route critical isolation findings back to the full solution review loop; surface non-critical findings as a summary
- [ ] Present a final implementation summary before stopping

### Non-Functional Requirements

- [ ] Fully generic — no hardcoded project names, module names, or technology stacks
- [ ] Each sub-agent receives full context in its invocation — no shared state between agents
- [ ] Areas must be implemented serially — the orchestrator must enforce this sequencing
- [ ] No tests are produced at any stage — the goal is implementation quality, not test coverage
- [ ] The orchestrator must not write code itself — all implementation work is delegated to sub-agents
- [ ] Reviews target critical and major issues only — style and minor nits are explicitly out of scope
- [ ] Graceful degradation: if a feature expert agent is not found, the area implementer proceeds with codebase exploration

---

## Agent Architecture

```
Master Skill (generic-work-item-implementation-start)
  │
  ├─ [Step 1] generic-work-item-impact-analyzer
  │     Reads: Technical Scope (areas, contracts, checklist)
  │     Produces: ordered impact queue with blast radius per area
  │
  ├─ [Step 2] generic-work-item-foundation-builder
  │     Reads: Technical Scope, impact queue
  │     Produces: zero-impact interfaces, models, connectors, contracts
  │
  ├─ [Step 2 Review] generic-work-item-code-reviewer (critical+major)
  │     Reads: foundation artifacts
  │     Produces: issue list (or "clean")
  │
  ├─ [Step 4 — serial loop, one area at a time]
  │   ├─ [pre-step] Glob agents/**/*<area>*expert*.md
  │   ├─ generic-work-item-area-implementer
  │   │     Reads: area scope, foundation artifacts, expert agent (if found)
  │   │     Produces: implementation of this area
  │   └─ generic-work-item-code-reviewer (critical+major)
  │         Reads: area implementation
  │         Produces: issue list (or "clean")
  │
  ├─ [Step 5] generic-work-item-code-reviewer (full scope)
  │     Reads: entire implementation
  │     Produces: holistic issue list (or "clean")
  │
  └─ [Step 6 — parallel, read-only] generic-work-item-isolation-reviewer (per area)
        Reads: implementation files for that area only
        Produces: isolation findings report
```

---

## Sub-Agents to Create

| Agent | Role | Runs In | Key Inputs |
|---|---|---|---|
| `generic-work-item-implementation-start` | Master orchestrator skill | Main context | Jira key, spec path, or pasted Technical Scope |
| `generic-work-item-impact-analyzer` | Simulate implementation blast radius; produce ordered area queue | Own context | Technical Scope, codebase |
| `generic-work-item-foundation-builder` | Create zero-impact shared artifacts (interfaces, models, contracts) | Own context | Technical Scope, impact queue |
| `generic-work-item-area-implementer` | Implement a single area using foundation artifacts and expert guidance | Own context | Area scope, foundation artifacts, expert agent path |
| `generic-work-item-code-reviewer` | Review implementation for critical and major issues | Own context | Files to review, scope (foundation / area / full) |
| `generic-work-item-isolation-reviewer` | Review one area in isolation — internal correctness, edge cases, contract adherence | Own context | Implementation files for the target area only |

Existing agents reused (from milestone 003):
- `generic-work-item-feature-technical-scope` — not consumed directly, but its output (Area Impact Blocks) is the primary input to this workflow
- `generic-work-item-technical-reviewer` — not consumed directly, but its output (Technical Scope) is the primary input to this workflow

Existing skills reused:
- `generic-spec` — used in paste-only mode to create a spec if none exists
- Feature expert agents in the consuming project (`agents/**/*<area>*expert*.md`) — discovered at runtime and passed to area implementers

---

## Orchestration Rules

### Serial enforcement
The master skill must not launch the next area agent until:
1. The current area agent has returned a complete result
2. The code reviewer for that area has returned "clean" (or all issues have been resolved)

The isolation reviewers in Step 6 are the only agents that run in parallel — and they are read-only.

### Expert agent discovery
Before each area implementation, the master skill runs:
```
Glob: agents/**/*<area-keyword>*expert*.md
```
`<area-keyword>` is derived from the area name **and** from the `## Keywords` section of the intention. Matching against both increases the chance of finding an expert agent when the area name differs from the product vocabulary used to name the agent file. If a match is found, the expert agent path is passed to the area implementer. The implementer must treat the expert agent as a first-class resource — not optional guidance.

### Review scope
`generic-work-item-code-reviewer` accepts a `scope` parameter:
- `foundation` — reviews only the zero-impact artifacts from Step 2
- `area:<name>` — reviews only the files modified by the named area implementation
- `full` — reviews the entire implementation holistically

### Fix loop
Whenever a reviewer returns issues:
1. The master skill expands a targeted fix sub-agent (using `generic-work-item-area-implementer` with a fix instruction)
2. The reviewer is re-launched on the same scope
3. This loops until the reviewer returns "clean" or the user chooses to proceed with known issues

---

## Scope Boundaries

| In Scope | Out of Scope |
|----------|--------------|
| Implementing all areas listed in the Technical Scope | Writing tests or test scaffolding |
| Building shared interfaces, models, and connectors | Refactoring code outside the Technical Scope |
| Reviewing and fixing critical and major issues | Style fixes, formatting, minor nits |
| Leveraging existing expert agents | Creating new expert agents |
| Isolation reviews per area | Performance benchmarking or profiling |
| Surfacing non-critical findings as a summary | Auto-fixing non-critical findings |

---

## Tasks

### Specification Phase (this milestone)
- [x] Write master spec document

### Implementation Phase (next milestones)
- [ ] Create `generic-work-item-impact-analyzer` agent (self-contained, independently invokable)
- [ ] Create `generic-work-item-foundation-builder` agent (self-contained, independently invokable)
- [ ] Create `generic-work-item-area-implementer` agent (handles expert discovery and leverage; self-contained)
- [ ] Create `generic-work-item-code-reviewer` agent (accepts scope parameter: foundation / area / full)
- [ ] Create `generic-work-item-isolation-reviewer` agent (read-only, single-area scope)
- [ ] Create `generic-work-item-implementation-start` master skill (orchestrates all agents above)
- [ ] Test: foundation-only run on a real Technical Scope (no area implementations)
- [ ] Test: single-area implementation with expert agent present
- [ ] Test: single-area implementation without expert agent (fallback to codebase exploration)
- [ ] Test: full end-to-end run with at least two areas; verify serial enforcement
- [ ] Test: isolation reviewers in parallel after full implementation
- [ ] Verify: no test files are created at any stage

---

## Dependencies

- `003_generic-work-item-pre-implementation-tech-scope` — upstream (Phase 3); produces the Technical Scope this skill consumes
- `002_generic-work-item-worktree-setup` — upstream (Phase 2); establishes the worktree CWD this skill writes into
- `002_generic-work-item-preparation` — upstream (Phase 1); produces the intention the Technical Scope is based on
- `generic-spec` skill — used in paste-only mode
- Atlassian MCP — required for Jira source; skill degrades gracefully when unavailable
- Feature expert agents in the consuming project — discovered at runtime; absence is handled gracefully

---

## Success Criteria

- Given a Technical Scope, the skill produces a complete implementation of all areas with no skipped steps
- The foundation is always built before any area is touched
- No two area agents ever run concurrently
- Every area that has a matching expert agent uses it
- Every increment (foundation, each area, full solution) passes a critical+major code review before the workflow advances
- Isolation reviewers run per area after the full review and surface any remaining issues
- The final summary clearly lists what was implemented, what issues were found and resolved, and what was out of scope
- No test files are created at any stage

---

## Open Questions

- Should the master skill support a `--dry-run` mode that produces the impact queue and foundation plan without writing any code?
- When the code reviewer finds issues in the full-scope review (Step 5) that originated in a specific area, should it re-run the per-area reviewer for that area or treat it as a new targeted fix?
- Should the isolation reviewer be allowed to propose fixes, or is it strictly read-only? Current design is read-only with critical findings routing back to Step 5.
- If two areas both depend on the same foundation contract and the contract needs to change mid-implementation, how should the master skill handle re-running the foundation builder?
- Should the impact queue in Step 1 be persisted (appended to the spec or Jira ticket) so the user can reference it in future sessions?

---

## Notes

- The "iron" metaphor reflects the goal: a hardened, reviewed, production-ready implementation — not a rough draft
- This skill intentionally does not produce tests. Test coverage is a separate concern addressed by a downstream workflow
- The serial area implementation constraint is a deliberate trade-off: it is slower than parallel execution but eliminates competing writes, merge conflicts, and cascading failures between areas
- Feature expert agents in the consuming project are the primary mechanism for domain knowledge injection — this skill assumes they exist for mature features and degrades gracefully when they do not
- `generic-work-item-isolation-reviewer` is the only agent that runs in parallel because it is read-only and scoped to a single area; it cannot introduce conflicts
