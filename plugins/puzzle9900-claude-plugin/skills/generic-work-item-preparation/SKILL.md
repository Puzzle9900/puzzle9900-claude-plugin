---
name: generic-work-item-preparation
description: Use when preparing a Jira ticket or work item before development begins — ticket quality is low, fields are missing, the title is unclear, or there is no structured description of intent yet
---

# generic-work-item-preparation

## Overview

Orchestrates a multi-phase pipeline that takes a Jira ticket — or a raw idea — from its initial state to a fully-defined, high-quality work item ready for development. Each phase runs as an isolated sub-agent and pauses for user confirmation before proceeding.

**Scope boundary:** this workflow captures intention (what and why), not solution (how). Solution design happens in a later, separate workflow.

## When to Use

- "Prepare ticket PROJ-123 before I start"
- "This ticket has no description / no sprint / no points"
- "I want to define a work item before coding"
- "Improve the quality of this ticket"
- No Jira ticket exists but the user wants to define work formally

**Not this skill:** if the user is ready to start implementation → use `generic-work-item-scope-definition`

## Steps

### 1. Detect input

Parse the user's message for:
- **Jira ticket key** (e.g. `PROJ-123`) or URL → fetch ticket with Atlassian MCP `searchJiraIssuesUsingJql`, fields: `["summary", "description", "status", "assignee", "sprint", "story_points", "components", "labels", "issuetype", "priority", "project"]`. Resolve contributor context using `generic-jira-contributor-context`, then proceed directly to Step 2 — no confirmation needed.
- **No ticket** → ask: "What do you want to work on? Give me a short description." Then ask: **"Should I also create a Jira ticket for this once the work item is fully defined? (yes / no)"** Store the answer for Step 7. Then show a one-line summary of the intent and ask: **"Ready to start the preparation pipeline? (yes / go back)"** Do not proceed until confirmed.

Resolve contributor context using `generic-jira-contributor-context` in both paths. Store: `accountId`, `displayName`, `team`, `sprint`.

### 2. Feature linking (sub-agent)

Invoke the `generic-work-item-feature-linker` agent. Pass:
- Current title (or the user's intent string)
- Ticket key, component, labels (or intent string)

Present the feature list (3–7 items, top-level only). Let the user trim or add items.

After the user confirms the list, ask: **"Feature list confirmed. Proceed to field audit? (yes / go back)"**

### 3. Field audit (sub-agent)

Invoke the `generic-work-item-field-auditor` agent. Pass:
- Full ticket JSON (or `null` in intent-only mode)
- Contributor context (team, sprint, accountId)
- Confirmed feature list from Step 2

Present the audit checklist. Wait for the user to approve, adjust, or skip individual field suggestions.

After approval, confirm: **"Field audit complete. Proceed to title improvement? (yes / go back)"**
If intent-only mode: skip this phase and proceed directly, noting it was skipped.

### 4. Title improvement (sub-agent)

Invoke the `generic-work-item-title-improver` agent. Pass:
- Current title (or the user's intent string)
- Platform context if known

Present the original and proposed title side by side. Wait for the user to accept, edit, or request another suggestion.

After approval, confirm: **"Title locked in. Proceed to intention definition? (yes / go back)"**

### 5. Intention definition (sub-agent)

Invoke the `generic-work-item-intention-writer` agent. Pass:
- Approved title from Step 4
- Any existing ticket description
- Confirmed feature list from Step 2
- Platform (from title or user)

Present the full intention draft. The user may revise any section. Wait for explicit approval of the complete intention.

After approval, ask: **"Intention approved. Proceed to final review? (yes / go back)"**

### 6. Final review

Aggregate and present everything in one view:

```
Title:    <original> → <approved>
Fields:   <changed fields list or "no changes">
Features: <confirmed feature list>

--- Intention ---
<full intention content>
```

Ask: **"Does this look right? Approve to save, or go back to any step (type the step number)."**

Do not proceed to Step 7 until the user explicitly approves.

### 7. Persist

**Ticket exists:**
- Update title via `editJiraIssue`
- Update changed fields via `editJiraIssue`
- Write the unified description produced by the intention writer (Step 5) as the new Jira description via `editJiraIssue` — the intention writer already merged and integrated any existing content, so this replaces the old description entirely

**No ticket, user said yes to Jira creation (Step 1):**
- Create a new Jira ticket via `createJiraIssue` using the approved title, fields, and the full intention as the description
- Ask the user which project to create it in if not already known

**No ticket, user declined Jira creation:**
- Skip Jira entirely

**Always — save a local spec:**
- Invoke `generic-spec` to save the full intention as a local project spec regardless of Jira outcome

Confirm with the ticket URL (new or updated) and local spec file path.

## Constraints

- Never proceed from one step to the next without explicit user confirmation — every step ends with a gating question
- Never update or create a Jira ticket without explicit user approval at Step 6
- The description written to Jira is always the unified output from the intention writer — never append, never patch; the intention writer owns the merge
- Always ask about Jira ticket creation at Step 1 when no ticket is provided — never assume
- Each sub-agent receives all needed context in its invocation prompt — do not rely on shared state
- Intention output must contain no solution language; if the sub-agent produces any, ask it to revise
- If a sub-agent is unavailable, state the gap clearly, skip that phase, and still ask for confirmation before continuing
- Always create a local spec (via `generic-spec`) even when Jira is updated or created — the spec is the canonical record
- If Atlassian MCP is unavailable, skip all Jira phases and work in local-only mode
