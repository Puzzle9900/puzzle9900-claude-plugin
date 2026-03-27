---
name: generic-work-item-technical-definition
description: Translates a clean intention (from a Jira ticket, a local spec file, or both) into a technical definition — which codebase areas are affected, what data contracts must exist, and a checklist of what must be true before implementation begins. Does not define how to implement.
---

# generic-work-item-technical-definition

## Overview

Bridges the gap between a clean intention (what and why) and implementation (how). Works from any source that contains a structured intention: a Jira ticket, a local spec file under `projectspecs/`, or both when they are linked. For each feature area, a sub-agent deeply reads the codebase and returns an **Area Impact Block**: relevant module paths, required data contracts, capability needs, and constraints. A final reviewer synthesizes all blocks into a unified **Technical Definition** that is appended back to whatever source(s) were used.

**Scope boundary:** this workflow identifies *where* things must happen and *what technical contracts must exist* — not *how* to implement them. Boundary is at the module/interface level, not method/line level.

## When to Use

- "Define the technical definition for PROJ-123"
- "Run the technical definition for projectspecs/002_checkout-flow/spec.md"
- "What technically needs to happen for this work item?"
- "Run the technical definition before I start implementing"
- After `generic-work-item-preparation` has finished — whether it produced a Jira ticket, a local spec, or both

**Not this skill:** if the intention is not yet defined (missing problem statement, unclear scope) → use `generic-work-item-preparation` first.

## Steps

### 0. Detect input

Parse the user's message for the following sources (one or more may be present):

| Input type | Detection | Action |
|---|---|---|
| **Jira ticket key** | e.g. `PROJ-123` or Jira URL | Fetch via Atlassian MCP |
| **Local spec path** | e.g. `projectspecs/002_name/spec.md` or spec number `002` | Read file directly |
| **Both linked** | Key present in spec file or spec path in Jira description | Load from both and cross-reference |
| **Context from previous step** | Running right after preparation | Source already known — proceed |
| **Nothing provided** | No identifiers in message | Ask: "What should I build the technical definition for? Provide a Jira ticket key, a spec path, or paste the intention directly." |

Store the **active source(s)** — this determines where the final Technical Definition is persisted in Step 6.

### 1. Load intention context

Load from each active source:

**From Jira ticket:**
- Fetch via Atlassian MCP (`searchJiraIssuesUsingJql` or `getJiraIssue`), fields: `["summary", "description", "status", "components", "labels", "issuetype", "priority", "project"]`
- If MCP unavailable: note it, skip Jira as a source, continue with local spec if available

**From local spec file:**
- Read the file at the provided path (or search `projectspecs/` by spec number or title keywords)
- If the file does not exist: warn the user and ask them to confirm the path or provide it

**Extract from whichever source(s) are loaded:**
- **Intention** (`## Intention` or `## Problem` + `## Intention`)
- **Acceptance Criteria** (`## Acceptance Criteria`)
- **Related Features** (`## Related Features`)
- **Platform** (from title tag `[iOS]`, `[Android]`, `[Web]`, `[Backend]`, or from content)

If neither source has a `## Related Features` section or intention: warn the user that the work item may not be fully prepared. Offer to proceed with what is available, or go back to run `generic-work-item-preparation` first.

If both sources are loaded and they conflict (e.g. different feature lists), surface the conflict and ask the user which to use as the canonical source before proceeding.

**Intent-only fallback:** if no source can be loaded and the user pastes context directly, accept it and work in paste-only mode — no Jira or spec updates at the end.

### 2. Confirm investigation scope

Display a summary for user confirmation:

```
Source: <Jira KEY — title> | <spec path> | both
Platform: <platform>
Features to investigate:
  1. <feature name>
  2. <feature name>
  ...
```

Ask: **"Should I investigate all these features, or would you like to add/remove any before I start?"**

Do not proceed until confirmed. If the user adjusts the list, update it and re-display before confirming.

### 3. Parallel feature investigation

For each confirmed feature, invoke the `generic-work-item-feature-technical-scope` agent. Run all agents **in parallel** — do not wait for one before launching the next.

Pass to each agent:
```
Feature: <feature name>
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
- Original ticket intention
- Acceptance criteria
- Platform

The reviewer produces the final **Technical Definition** in the canonical output format.

### 5. User approval

Present the full Technical Definition to the user:

```
## Technical Definition

### Scope Summary
<...>

### Areas of Impact
<per-feature blocks>

### Technical Checklist
<unified checklist>

### Open Technical Questions
<...>
```

Ask: **"Does this technical definition look right? Approve to save, request edits, or flag specific items to revisit."**

Allow free-text corrections before persisting. If the user requests changes to specific areas, update those items inline and re-present the affected section before saving.

Do not persist until explicitly approved.

### 6. Persist

Persist back to every active source identified in Step 0. Always append — never overwrite existing sections.

**Jira (active source = Jira or both):**
- Append `## Technical Definition` as a new section to the existing ticket description
- Use `editJiraIssue` to update the description
- If MCP became unavailable after Step 1: skip silently, report at the end

**Local spec file (active source = spec or both):**
- Append the Technical Definition section to the spec file that was read in Step 1
- Write directly to the file — do not create a new spec

**No active source (paste-only mode):**
- Offer to save to a new local spec via `generic-spec`, or skip
- Do not attempt Jira update

Confirm at the end with: each source that was updated (Jira URL and/or spec file path), and any source that was skipped with the reason.

## Constraints

- Never proceed from step to step without explicit user confirmation — every step ends with a gate
- Never persist (Jira or spec) without Step 5 approval
- Never define *how* to implement — only *what must exist* and *where*
- Never invent file paths or contract names that were not discovered by reading the actual codebase
- Each sub-agent receives complete context in its invocation prompt — do not rely on shared state between agents
- The Technical Definition always appends to existing content — never replaces intention or other sections
- If a feature agent returns no findings (e.g. code path not found), surface this gap explicitly rather than silently omitting it
- If Atlassian MCP is unavailable, skip Jira as a source and persist to local spec only; if local spec is also unavailable, offer paste-only mode
- If both Jira and spec are active sources and they conflict, always ask the user which is canonical before proceeding — never silently prefer one
- Boundary enforcement: if any output contains implementation language (method names, syntax, injection patterns), ask the reviewer to strip it before presenting to the user

## Boundary Reference

Use this to judge whether output is in scope:

| Allowed — Technical Definition | Not Allowed — Implementation |
|-------------------------------|------------------------------|
| `SavedPaymentMethod { id, lastFour, type }` | `data class SavedPaymentMethod(val id: String...)` |
| "PaymentRepository needs CRUD for SavedPaymentMethod" | "Add `save(method)` to `PaymentRepositoryImpl`" |
| "Checkout module needs persistent access to payment methods" | "Inject PaymentRepository into CheckoutViewModel" |
| "event: `payment_method_saved`, attrs: `method_type`, `is_default`" | "Call `analytics.track("payment_method_saved")`" |
| "Encryption constraint on payment data" | "Use AES-256 via Android Keystore" |
