# Generic Work Item Pre-Implementation Tech Scope

**Milestone**: 003_generic-work-item-pre-implementation-tech-scope
**Created**: 2026-03-26
**Status**: Draft

## Overview

A master skill that takes a work item with a clean, structured intention and produces a complete **Technical Specification** document saved in `projectspecs/`. It identifies which areas of the codebase are affected, what data contracts must exist, and a checklist of what must be true before implementation begins. It does not specify how to implement anything. Jira is used only as a read source — nothing is written back to it.

This skill is the third step in the work item pipeline:

```
generic-work-item-preparation
  → (clean intention, Jira updated)
generic-work-item-worktree-setup
  → (worktree created, CWD = feature branch)
generic-work-item-pre-implementation-tech-scope   ← this milestone
  → (technical scope: areas, contracts, checklist)
generic-work-item-implementation-start
  → (implemented solution, reviewed and verified)
generic-work-item-ship
  → (draft PR, approved)
```

---

## Workflow

```
User invokes skill with Jira key, spec path, or both
        │
        ▼
Step 0: Detect source(s)
  ├─ Jira ticket key → fetch via Atlassian MCP
  ├─ Local spec path → read projectspecs/ file
  ├─ Both → load and cross-reference
  └─ Neither → ask user or accept pasted intent
        │
        ▼
Step 1: Extract intention, AC, keywords, related features, platform
        │
        ▼
Step 2: Gate — confirm feature list with user
        │
        ▼
Step 3: Launch one sub-agent per feature (in parallel)
  pre-step: search agents/**/*<feature>*expert*.md for each feature
  agent: generic-work-item-feature-technical-scope
  Each agent runs:
    Phase 0: read local expert agent if found (code paths, constraints, patterns)
    Phase 1: map sub-areas (Glob/Grep)
    Phase 2: investigate sub-areas in parallel
    Phase 3: merge into Area Impact Block:
      - Module path
      - Data contracts
      - Capability needs
      - Dependencies
      - Constraints
      - Checklist items
        │
        ▼
Step 4: Reviewer synthesizes all blocks
  agent: generic-work-item-technical-reviewer
  Produces:
    - Scope Summary
    - Areas of Impact (cleaned, de-duplicated)
    - Technical Checklist (unified, ordered)
    - Open Technical Questions
        │
        ▼
Step 5: Gate — user approves or edits
        │
        ▼
Step 6: Save
  └─ Create projectspecs/<number>_<name>/technical-scope.md
       (or as sibling if a spec.md already exists for this work item)
```

---

## Goals

- Allow developers to understand the technical landscape of a work item *before* implementation begins
- Define required data contracts (names, shapes) without prescribing language-specific syntax
- Identify which modules need new capabilities, at the interface/boundary level only
- Surface cross-cutting concerns (analytics events, auth, encryption, error states) that span features
- Produce a unified checklist of what must be true, not what to code

## Requirements

### Functional Requirements

- [ ] Accept a Jira ticket key, a local spec path, or both as input
- [ ] Fall back gracefully when only one source is available (MCP down, no spec file)
- [ ] Accept pasted intention text when no source can be loaded (paste-only mode)
- [ ] Detect and surface conflicts when Jira and spec disagree on features or intention
- [ ] Confirm feature list with user before investigation begins (user can add/remove)
- [ ] Before launching feature agents, search the consuming project's `agents/` directory for local feature expert agents matching each feature name
- [ ] Pass the expert agent path (or `"none"`) to each feature scope agent alongside other context
- [ ] Launch one `generic-work-item-feature-technical-scope` agent per feature, in parallel
- [ ] Pass each feature agent: feature name, expert agent path, code path hints, intention, acceptance criteria, platform, keywords (used as Glob/Grep seeds)
- [ ] Launch one `generic-work-item-technical-reviewer` agent after all feature agents complete
- [ ] Gate on user approval of the Technical Specification before saving
- [ ] Never write back to Jira — it is a read-only source
- [ ] Never modify existing spec files — always create a new `technical-scope.md`
- [ ] Create `projectspecs/<number>_<name>/technical-scope.md` as the canonical output
- [ ] If a `spec.md` already exists for this work item, create `technical-scope.md` as a sibling in the same folder
- [ ] Report the path of the created file on completion

### Non-Functional Requirements

- [ ] No implementation language in output (no method names, language syntax, injection patterns)
- [ ] Each sub-agent receives full context in its invocation — no shared state between agents
- [ ] If a feature agent returns "module not found", surface the gap visibly rather than silently omitting it
- [ ] Graceful degradation: skill must be usable even when Jira MCP is unavailable or codebase is absent

---

## Technical Approach

### Scope Boundary

The skill enforces a strict boundary between *technical definition* and *implementation*:

| Allowed | Not Allowed |
|---------|-------------|
| `SavedPaymentMethod { id: String, lastFour: String }` | `data class SavedPaymentMethod(val id: String)` |
| "PaymentRepository needs CRUD for SavedPaymentMethod" | "Add `save()` to PaymentRepositoryImpl" |
| "event: `payment_saved`, attrs: `method_type`, `is_default`" | "Call `analytics.track("payment_saved")`" |
| "must be encrypted at rest" | "Use AES-256 via Android Keystore" |

### Agent Architecture

```
Master Skill (generic-work-item-pre-implementation-tech-scope)
  │
  ├─ [pre-step] Glob agents/**/*<feature>*expert*.md for each feature
  │     → if found: pass expert agent path to feature scope agent
  │     → if not found: pass "none", agent falls back to codebase exploration
  │
  ├─ [parallel] generic-work-item-feature-technical-scope (feature 1)
  │     Phase 0: read local expert agent (if available) → extract code paths + constraints
  │     Phase 1: map sub-areas via Glob/Grep
  │     Phase 2: investigate sub-areas in parallel
  │     Phase 3: merge into Area Impact Block
  │
  ├─ [parallel] generic-work-item-feature-technical-scope (feature 2)
  ├─ [parallel] generic-work-item-feature-technical-scope (feature N)
  │
  └─ [sequential, after all] generic-work-item-technical-reviewer
```

### Output Format (canonical, appended to sources)

```markdown
## Technical Scope

### Scope Summary
<2-3 sentences: what the system must technically support>

### Areas of Impact
**[ModuleName]** (`path/to/module/`)
  - Data contract: `ContractName { field: Type }`
  - Needs: <capability>
  - Depends on: <module>
  - Constraints: <constraint>

**Cross-cutting**
  - <concern spanning multiple areas>

### Technical Checklist
- [ ] Define `ContractName` shape
- [ ] [Module]: <capability that must exist>
- [ ] Cross-cutting: <constraint>

### Open Technical Questions
- <unresolved ambiguity>
```

### Source Handling

| Active source(s) | Load from | Output |
|---|---|---|
| Jira only | Atlassian MCP (read-only) | New `projectspecs/<number>_<name>/technical-scope.md` |
| Local spec only | File read (read-only) | `technical-scope.md` sibling in same spec folder |
| Both | Both (read-only) | `technical-scope.md` sibling in existing spec folder, or new folder if none |
| Paste-only | User paste | New `projectspecs/<number>_<name>/technical-scope.md` |

---

## Tasks

- [x] Write master skill: `skills/generic-work-item-technical-definition/SKILL.md`
- [x] Write feature investigator agent: `agents/generic-work-item-feature-technical-scope.md`
- [x] Write reviewer/synthesizer agent: `agents/generic-work-item-technical-reviewer.md`
- [x] Support local spec as input source alongside Jira ticket
- [ ] Test flow end-to-end with a real ticket + spec pair
- [ ] Test graceful degradation: Jira MCP unavailable
- [ ] Test graceful degradation: codebase absent (module not found)
- [ ] Test paste-only mode

---

## Dependencies

- `002_generic-work-item-worktree-setup` — upstream (Phase 2); establishes the worktree CWD where technical-scope.md will be saved
- `002_generic-work-item-preparation` — upstream (Phase 1); produces the clean intention this skill consumes
- `generic-spec` skill — used in paste-only mode to create a new spec if none exists
- `generic-jira-contributor-context` — not required by this skill (already resolved upstream)
- Atlassian MCP — required for Jira source; skill degrades gracefully when unavailable

---

## Success Criteria

- A developer can run this skill after preparation and receive a complete `technical-scope.md` document without writing any code
- The output is free of implementation language and can be read by a non-engineer to understand what the system must support
- The document is always created as a new file — Jira and existing spec files are never modified
- Feature agents correctly identify module paths and data contracts from the actual codebase
- The reviewer surfaces cross-cutting concerns (analytics events, auth, error states) not caught by individual feature agents
- Gaps (modules not found) are surfaced explicitly rather than silently omitted

---

## Notes

- This skill intentionally sits *between* intention and implementation — it does not produce a sprint plan, a PR, or a code diff
- The "technical definition" concept is analogous to a mini ADR (Architecture Decision Record) focused on scope and contracts, not decisions
- For analytics/observability use cases, the output should name event identifiers and attribute keys — exactly the level of detail needed to instrument later without ambiguity
- Related future skill (not in scope here): a skill that takes the Technical Checklist and turns it into an ordered implementation plan
