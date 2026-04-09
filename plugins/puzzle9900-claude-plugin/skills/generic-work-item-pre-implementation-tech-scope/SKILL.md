---
name: generic-work-item-pre-implementation-tech-scope
description: Use when a work item has a clean intention and you need to understand the technical landscape before implementation begins — investigates affected codebase areas, defines required data contracts, and produces a full technical specification document in projectspecs/ ready to guide implementation. Works from a Jira ticket, a local spec file, or both as read sources. Does not define how to implement.
---

# generic-work-item-pre-implementation-tech-scope

## Overview

Bridges the gap between a clean intention (what and why) and implementation (how). Reads the work item from a Jira ticket, a local spec file under `projectspecs/`, or both. For each related feature area, a sub-agent deeply reads the codebase and returns an **Area Impact Block**: relevant module paths, required data contracts, capability needs, and constraints. A final reviewer synthesizes all blocks into a complete **Technical Specification** document that is saved as a new entry in `projectspecs/`.

Nothing is written back to Jira — Jira is a read-only source in this workflow. The canonical output is always a local `projectspecs/` document.

**Scope boundary:** this workflow identifies *where* things must happen and *what technical contracts must exist* — not *how* to implement them. Boundary is at the module/interface level, not method/line level.

## When to Use

- "Run the pre-implementation tech scope for PROJ-123"
- "Run the pre-implementation tech scope for projectspecs/002_checkout-flow/spec.md"
- "What technically needs to happen for this work item?"
- "Scope the technical requirements before I start implementing"
- After `generic-work-item-preparation` has finished — whether it produced a Jira ticket, a local spec, or both

**Not this skill:** if the intention is not yet defined (missing problem statement, unclear scope) → use `generic-work-item-preparation` first.

## Steps

### 0. Detect input

Parse the user's message for the following read sources (one or more may be present):

| Input type | Detection | Action |
|---|---|---|
| **Jira ticket key** | e.g. `PROJ-123` or Jira URL | Fetch via Atlassian MCP — read only |
| **Local spec path** | e.g. `projectspecs/002_name/spec.md` or spec number `002` | Read file directly |
| **Both linked** | Key present in spec file or spec path in Jira description | Load from both and cross-reference |
| **Context from previous step** | Running right after preparation | Source already known — proceed |
| **Nothing provided** | No identifiers in message | Ask: "What should I build the technical scope for? Provide a Jira ticket key, a spec path, or paste the intention directly." |

Note: sources are **read-only** — this skill never writes back to Jira or modifies existing spec files.

### 1. Load intention context

Load from each active source:

**From Jira ticket:**
- Fetch via Atlassian MCP (`searchJiraIssuesUsingJql` or `getJiraIssue`), fields: `["summary", "description", "status", "components", "labels", "issuetype", "priority", "project"]`
- If MCP unavailable: note it, skip Jira as a source, continue with local spec if available

**From local spec file:**
- Read the file at the provided path (or search `projectspecs/` by spec number or title keywords)
- If the file does not exist: warn the user and ask them to confirm the path or provide it

**Extract from whichever source(s) are loaded:**
- **Title** (ticket summary or spec title — used to name the new spec document)
- **Intention** (`## Intention` or `## Problem` + `## Intention`)
- **Acceptance Criteria** (`## Acceptance Criteria`)
- **Related Features** (`## Related Features`)
- **Platform** (from title tag `[iOS]`, `[Android]`, `[Web]`, `[Backend]`, or from content)

If neither source has a `## Related Features` section or intention: warn the user that the work item may not be fully prepared. Offer to proceed with what is available, or go back to run `generic-work-item-preparation` first.

If both sources are loaded and they conflict (e.g. different feature lists), surface the conflict and ask the user which to use as the canonical source before proceeding.

**Intent-only fallback:** if no source can be loaded and the user pastes context directly, accept it and proceed — the output spec will still be created.

### 2. Confirm investigation scope

Display a summary for user confirmation:

```
Source: <Jira KEY — title> | <spec path> | both (read-only)
Platform: <platform>
Features to investigate:
  1. <feature name>
  2. <feature name>
  ...
Output: new projectspecs/ document
```

Ask: **"Should I investigate all these features, or would you like to add/remove any before I start?"**

Do not proceed until confirmed. If the user adjusts the list, update it and re-display before confirming.

**Autonomous mode:** skip confirmation — proceed immediately with the discovered feature list.

### 3. Parallel feature investigation

Before launching feature agents, check for local feature expert agents in the consuming project:
- Glob `agents/**/*-<feature-keyword>*expert*.md` and `agents/**/*<feature-keyword>*.md` for each feature
- If a match is found, it is a specialized agent with deep context about that feature — pass its path to the feature scope agent so it can be invoked as a primary source before any codebase exploration

For each confirmed feature, invoke the `generic-work-item-feature-technical-scope` agent. Run all agents **in parallel** — do not wait for one before launching the next.

Pass to each agent:
```
Feature: <feature name>
Feature expert agent: <path to local agent file, or "none">
Code path hints: <hints from Related Features list, e.g. "checkout/", "PaymentRepository">
Ticket intention: <full intention section text>
Acceptance criteria: <full AC list>
Platform: <platform>
```

Each agent returns a structured **Area Impact Block**:
```
Feature: <name>
Module path: <discovered path>
Data contracts:
  - ContractName { field: Type, field: Type }
Needs:
  - <capability at module level>
Depends on:
  - <other modules or services>
Constraints:
  - <technical constraints: encryption, auth, threading, etc.>
Checklist items:
  - [ ] <what must be true>
```

### 4. Synthesize

Once all feature agents have returned, aggregate their Area Impact Blocks. Invoke the `generic-work-item-technical-reviewer` agent with:
- All Area Impact Blocks (full content)
- Work item title
- Original intention
- Acceptance criteria
- Platform
- Source reference (Jira key and/or spec path — for linking in the output doc)

The reviewer produces a complete **Technical Specification** in the canonical document format.

### 5. User approval

Present the full Technical Specification to the user and ask: **"Does this technical specification look right? Approve to save, request edits, or flag specific items to revisit."**

Allow free-text corrections before saving. If the user requests changes to specific areas, update those items inline and re-present the affected section before saving.

Do not save until explicitly approved.

**Autonomous mode:** skip approval — save the Technical Specification immediately.

### 6. Save to projectspecs/

Create a new project spec document using the `generic-spec` skill pattern:

- Determine the next available spec number (find the highest `###_*` folder under `projectspecs/` and increment)
- Derive a kebab-case folder name from the work item title (e.g. `checkout-saved-payment-methods`)
- Create `projectspecs/<number>_<name>/technical-scope.md` with the full Technical Specification content
- If a `spec.md` already exists for this work item (linked from source), create `technical-scope.md` as a sibling document in the same folder rather than a new numbered folder

Confirm with: the path to the created file and the source(s) it was derived from.

## Constraints

- In auto or autonomous mode, do not end your response turn between steps — execute all steps in sequence without stopping; only pause at explicit user gates in pause mode
- Never proceed from step to step without explicit user confirmation — every step ends with a gate
- Never save without Step 5 approval
- Never write back to Jira — it is a read-only source
- Never modify existing spec files — always create a new `technical-scope.md`
- Never define *how* to implement — only *what must exist* and *where*
- Never invent file paths or contract names that were not discovered by reading the actual codebase
- Each sub-agent receives complete context in its invocation prompt — do not rely on shared state between agents
- If a feature agent returns no findings (e.g. code path not found), surface this gap explicitly rather than silently omitting it
- If Atlassian MCP is unavailable, skip Jira as a source and continue with local spec or pasted intent
- If both Jira and spec are active sources and they conflict, always ask the user which is canonical before proceeding
- Boundary enforcement: if any output contains implementation language (method names, syntax, injection patterns), ask the reviewer to strip it before presenting to the user

## Boundary Reference

Use this to judge whether output is in scope:

| Allowed — Technical Scope | Not Allowed — Implementation |
|-------------------------------|------------------------------|
| `SavedPaymentMethod { id, lastFour, type }` | `data class SavedPaymentMethod(val id: String...)` |
| "PaymentRepository needs CRUD for SavedPaymentMethod" | "Add `save(method)` to `PaymentRepositoryImpl`" |
| "Checkout module needs persistent access to payment methods" | "Inject PaymentRepository into CheckoutViewModel" |
| "event: `payment_method_saved`, attrs: `method_type`, `is_default`" | "Call `analytics.track("payment_method_saved")`" |
| "Encryption constraint on payment data" | "Use AES-256 via Android Keystore" |
