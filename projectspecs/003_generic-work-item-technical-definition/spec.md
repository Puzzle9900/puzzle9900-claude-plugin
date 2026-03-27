# Generic Work Item Technical Definition

**Milestone**: 003_generic-work-item-technical-definition
**Created**: 2026-03-26
**Status**: Draft

## Overview

A master skill that takes a work item with a clean, structured intention and produces a **Technical Definition** — the technical translation of that intention. It identifies which areas of the codebase are affected, what data contracts must exist, and a checklist of what must be true before implementation begins. It does not specify how to implement anything.

This skill is the third step in the work item pipeline:

```
generic-work-item-preparation
  → (clean intention, defined features)
generic-work-item-technical-definition   ← this milestone
  → (technical definition: areas, contracts, checklist)
[implementation]
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
Step 1: Extract intention, AC, related features, platform
        │
        ▼
Step 2: Gate — confirm feature list with user
        │
        ▼
Step 3: Launch one sub-agent per feature (in parallel)
  agent: generic-work-item-feature-technical-scope
  Each returns an Area Impact Block:
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
Step 6: Persist
  ├─ Append ## Technical Definition to Jira ticket (if active source)
  └─ Append ## Technical Definition to local spec file (if active source)
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
- [ ] Launch one `generic-work-item-feature-technical-scope` agent per feature, in parallel
- [ ] Pass each feature agent: feature name, code path hints, intention, acceptance criteria, platform
- [ ] Launch one `generic-work-item-technical-reviewer` agent after all feature agents complete
- [ ] Gate on user approval of the Technical Definition before persisting
- [ ] Append `## Technical Definition` to Jira ticket description (never overwrite)
- [ ] Append `## Technical Definition` to local spec file that was read (never create a new one unless in paste-only mode)
- [ ] Report which sources were updated and which were skipped (with reason)

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
Master Skill (generic-work-item-technical-definition)
  │
  ├─ [parallel] generic-work-item-feature-technical-scope (feature 1)
  ├─ [parallel] generic-work-item-feature-technical-scope (feature 2)
  ├─ [parallel] generic-work-item-feature-technical-scope (feature N)
  │
  └─ [sequential, after all] generic-work-item-technical-reviewer
```

### Output Format (canonical, appended to sources)

```markdown
## Technical Definition

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

| Active source(s) | Load from | Persist to |
|---|---|---|
| Jira only | Atlassian MCP | Jira description (append) |
| Local spec only | File read | Same spec file (append) |
| Both | Both | Both (append to each) |
| Paste-only | User paste | Offer `generic-spec` or skip |

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

- `002_generic-work-item-preparation` — upstream; produces the clean intention this skill consumes
- `generic-spec` skill — used in paste-only mode to create a new spec if none exists
- `generic-jira-contributor-context` — not required by this skill (already resolved upstream)
- Atlassian MCP — required for Jira source; skill degrades gracefully when unavailable

---

## Success Criteria

- A developer can run this skill after preparation and receive a Technical Definition without writing any code
- The output is free of implementation language and can be read by a non-engineer to understand what the system must support
- The Technical Definition is appended to both the Jira ticket and local spec without overwriting any existing sections
- Feature agents correctly identify module paths and data contracts from the actual codebase
- The reviewer surfaces cross-cutting concerns (analytics events, auth, error states) not caught by individual feature agents
- Gaps (modules not found) are surfaced explicitly rather than silently omitted

---

## Notes

- This skill intentionally sits *between* intention and implementation — it does not produce a sprint plan, a PR, or a code diff
- The "technical definition" concept is analogous to a mini ADR (Architecture Decision Record) focused on scope and contracts, not decisions
- For analytics/observability use cases, the output should name event identifiers and attribute keys — exactly the level of detail needed to instrument later without ambiguity
- Related future skill (not in scope here): a skill that takes the Technical Checklist and turns it into an ordered implementation plan
