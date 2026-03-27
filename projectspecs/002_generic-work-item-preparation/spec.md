# Generic Work Item Preparation

**Milestone**: 002_generic-work-item-preparation
**Created**: 2026-03-26
**Status**: Draft

## Overview

A master orchestration workflow that takes a Jira ticket — or a raw idea with no ticket — from its initial state to a fully-defined, high-quality work item ready to begin development. The workflow runs interactively, pausing for user confirmation at each phase, and concludes by persisting the enriched definition back to Jira or as a local product spec file.

This is not a single skill but a coordinated pipeline of sub-agents. Each sub-agent owns one responsibility, runs in its own isolated context, and is described completely enough to operate independently. The master skill launches each sub-agent via the Agent tool and acts only as a coordinator — collecting results, presenting them to the user, and deciding what comes next.

**Important scope boundary**: this workflow captures the **intention** — what we want to achieve and why. It does not define the solution or implementation approach. Solution design is a separate, later phase that iterates on top of the fully-defined intent produced here.

---

## Goals

- Ensure every Jira ticket reaches a minimum quality bar (fields, title, description) before development starts
- Produce a structured product definition that communicates intent, platform, acceptance criteria, and related features
- Give the user control and approval at every step — no silent mutations
- Work whether or not a Jira ticket already exists
- Be fully generic and reusable across any project or team

---

## Workflow Phases

### Phase 0 — Input Detection

**Trigger**: User invokes the master skill with a ticket ID, a URL, or a plain description of what they want to work on.

**Logic**:
- If a Jira ticket ID is provided → fetch the ticket via Atlassian MCP tools and load its current state
- If no ticket ID is provided → prompt the user for a short intent statement; all subsequent phases operate on a local-only spec

**Output**: A working context object containing either the fetched Jira ticket or the user-supplied intent string.

---

### Phase 1 — Jira Field Quality Audit

**Skill (future)**: `generic-work-item-field-auditor`

**Responsibility**: Check that all required Jira fields are populated. Flag missing or incomplete fields and offer to fill them interactively.

**Fields to audit**:
| Field | Check |
|---|---|
| Sprint | Assigned to an active or upcoming sprint |
| Story Points | Non-zero numeric estimate |
| Assignee | Has a named assignee |
| Team | Correct team label or component-level team |
| Component / Nature | At least one component selected |
| Issue Type | Bug, Story, Task, etc. — matches intent |
| Priority | Explicitly set (not default) |
| Labels | Any required labels present |
| Epic Link | Linked to a parent epic if applicable |

**Behavior**:
- Present the audit results as a checklist to the user
- For each missing field, offer a suggested value and ask for approval before writing
- Use `generic-jira-contributor-context` to resolve the correct assignee, team, and sprint from the authenticated user's context
- Do not write any field changes until the user approves the full set

**User confirmation**: Yes/no per field, or bulk-approve all suggestions.

---

### Phase 2 — Title Improvement

**Skill (future)**: `generic-work-item-title-improver`

**Responsibility**: Rewrite the ticket title (or working title, if no ticket) to be clear, unambiguous, and platform-aware.

**Rules for a good title**:
- Must include the platform: `[iOS]`, `[Android]`, `[Web]`, `[Backend]`, `[Cross-Platform]`, etc.
- Must express the intent as an action: "Add", "Fix", "Migrate", "Refactor", "Remove", "Enable", etc.
- Must be specific enough to stand alone — no pronouns, no vague nouns ("thing", "issue", "stuff")
- Should be ≤ 80 characters
- Should not duplicate the epic title

**Behavior**:
- Present the current title and the proposed improved title side by side
- Explain the changes made and why
- Ask for user approval before updating

**User confirmation**: Accept as-is, edit manually, or ask for another suggestion.

---

### Phase 3 — Intention Definition

**Sub-agent (future)**: `generic-work-item-intention-writer`

**Responsibility**: Articulate the **intention** of the work item — what problem exists, why it matters, and what a successful outcome looks like — without prescribing how it will be solved.

This sub-agent is strictly about "what and why", not "how". It does not propose architecture, implementation steps, or technical approaches. Those belong to a later, separate workflow that iterates on top of this definition.

**Intention template**:
```
## Problem
What is the current situation that needs to change? Who is affected and how?

## Intention
What do we want to be true after this work is done? Expressed as an outcome, not a solution.

## Platform
Which platform(s) are in scope: iOS, Android, Web, Backend, Cross-Platform?

## Acceptance Criteria
Observable, testable conditions that confirm the intention was met — not implementation steps.
- [ ] Criterion 1
- [ ] Criterion 2

## Related Features
Top-level features that this work item touches or depends on (populated by generic-work-item-feature-linker).

## Out of Scope
What is explicitly excluded from this work item to keep its boundary clear.

## Open Questions
Unresolved questions that must be answered before or during implementation.
```

**Behavior**:
- Draft all sections using the ticket title, any existing description, and the output of `generic-work-item-feature-linker`
- Keep acceptance criteria behavioral ("the user can…", "the system returns…") — never implementation-level ("add a method to…")
- Present the full draft section by section; allow the user to revise any section without a full rewrite
- Do not include solution language: no architecture choices, no library names, no code references

**User confirmation**: Section-by-section or full-draft approval.

---

### Phase 4 — Feature Linking

**Sub-agent (future)**: `generic-work-item-feature-linker`

**Responsibility**: Identify which existing features or product areas are related to this work item at a **top level only**. This sub-agent surfaces entry points and high-level characteristics — it does not deep-dive into feature internals, implementation details, or full knowledge graphs.

**What it produces**:
- A short list (3–7 items) of features or product areas that are most likely touched
- For each: feature name, one-line description of the relationship, and whether the relationship is direct (this ticket modifies the feature) or indirect (this ticket depends on or is adjacent to the feature)
- No code paths, no class names, no deep architectural notes — just enough for the intention writer and the user to understand the feature landscape at a glance

**Behavior**:
- Search Jira for epics and features related to the ticket's keywords, labels, and component
- If a local codebase is available, identify top-level module or folder names only — do not read file internals
- Stop at the first meaningful level of abstraction; do not recurse into sub-features
- Present the list to the user and let them trim or add items before it is passed to the intention writer

**User confirmation**: Confirm or adjust the feature list before it feeds into Phase 3.

---

### Phase 5 — Final Review

**Responsibility**: Master skill aggregates all enriched content and presents the full work item definition for a final holistic review before persisting.

**Presented view**:
- Title (original → improved)
- All audited/updated Jira fields
- Full enriched description
- Feature links

**User confirmation**: Approve to persist, or go back to any phase for revisions.

---

### Phase 6 — Persist

**Behavior**:
- **Ticket exists**: Update the Jira ticket via Atlassian MCP — title, all changed fields, and description
- **No ticket**: Save the enriched content as a local product spec file under `projectspecs/` using the `generic-spec` skill format

**Output**: A confirmation message with the Jira ticket URL or local file path.

---

## Orchestration Model

The master skill (`generic-work-item-preparation`) is the entry point and coordinator. It does not perform analysis itself — it launches sub-agents, collects their outputs, presents results to the user, and decides what happens next.

**Sub-agent model**: each phase is delegated to a dedicated sub-agent launched via the Agent tool. Sub-agents run in their own isolated context. They receive all the inputs they need in their prompt and return a structured result. They are independently invokable — any sub-agent can be run directly by the user without going through the master skill.

**Orchestration steps**:
1. Phase 0 — master skill handles input detection directly (lightweight, no sub-agent needed)
2. Phase 1 — launch `generic-work-item-field-auditor` sub-agent; present audit results; get user approval
3. Phase 2 — launch `generic-work-item-title-improver` sub-agent; present proposed title; get user approval
4. Phase 3+4 — launch `generic-work-item-feature-linker` sub-agent first (lightweight, fast); then launch `generic-work-item-intention-writer` sub-agent with feature list as input; present intention draft; get user approval
5. Phase 5 — master skill aggregates all outputs for final review
6. Phase 6 — master skill persists the approved content via Atlassian MCP or `generic-spec`

Supporting context used throughout: `generic-jira-contributor-context` — called once in Phase 0 to resolve the authenticated user's identity, team, and active sprint, then passed as context to sub-agents that need it.

### Orchestration Flow Diagram

```
User invokes /generic-work-item-preparation [TICKET-ID or intent]
        │
        ▼
Phase 0: Input Detection (master skill)
  + generic-jira-contributor-context → user identity, team, sprint
        │
        ├─ Ticket found ──────────────────────────────────────┐
        │                                                      │
        ▼                                                      ▼
Phase 1: Field Audit                               (No ticket: capture intent)
  → sub-agent: generic-work-item-field-auditor                │
        │ user approves field changes                         │
        ▼                                                      │
Phase 2: Title Improvement                                    │
  → sub-agent: generic-work-item-title-improver              │
        │ user approves title                                 │
        ▼                                                     │
Phase 4: Feature Linking (runs first, feeds Phase 3)         │
  → sub-agent: generic-work-item-feature-linker ◄────────────┘
        │ user confirms feature list
        ▼
Phase 3: Intention Definition
  → sub-agent: generic-work-item-intention-writer
        │ user approves intention
        ▼
Phase 5: Final Review (master skill — no sub-agent)
        │ user approves
        ▼
Phase 6: Persist (master skill)
  ├─ Jira ticket → update via Atlassian MCP
  └─ No ticket  → save via generic-spec
```

---

## Sub-Agents to Create

Each entry below is a self-contained sub-agent with an independent agent definition file. Any sub-agent can be invoked directly by the user without going through the master skill. Each agent definition must fully describe its own purpose, inputs, outputs, and behavior — it cannot rely on context inherited from the master skill.

| Agent | Role | Runs In | Depends On |
|---|---|---|---|
| `generic-work-item-preparation` | Master orchestrator skill | Main context | All sub-agents below |
| `generic-work-item-field-auditor` | Audit Jira fields; suggest and apply fixes | Own sub-agent context | `generic-jira-contributor-context`, Atlassian MCP |
| `generic-work-item-title-improver` | Rewrite title: platform tag + clear action intent | Own sub-agent context | — |
| `generic-work-item-feature-linker` | Surface top-level related features (entry points only, no deep dives) | Own sub-agent context | Atlassian MCP, optional codebase |
| `generic-work-item-intention-writer` | Write intention definition: problem, outcome, acceptance criteria — no solution | Own sub-agent context | Output of `generic-work-item-feature-linker` |

Existing skills reused:
- `generic-jira-contributor-context` — already exists (provides identity, team, sprint)
- `generic-spec` — already exists (used in Phase 6 when no Jira ticket exists)

---

## Requirements

### Functional Requirements
- [ ] Detect whether input is a Jira ticket ID or a free-form intent
- [ ] Fetch existing Jira ticket content when a ticket ID is provided
- [ ] Audit all required Jira fields and surface gaps to the user
- [ ] Suggest corrected field values using contributor context (team, sprint, assignee)
- [ ] Rewrite ticket title to include platform tag and clear action verb
- [ ] Surface top-level related features (entry points only — no deep feature analysis)
- [ ] Write an intention definition: problem, desired outcome, acceptance criteria — no solution design
- [ ] Present the full enriched work item for final review before persisting
- [ ] Update Jira ticket via Atlassian MCP when a ticket exists
- [ ] Save enriched content as a local spec file when no ticket exists
- [ ] Pause for user confirmation at every phase — no silent writes

### Non-Functional Requirements
- [ ] Fully generic — no hardcoded project names, teams, or conventions
- [ ] Each sub-agent must be independently invokable outside the master orchestrator
- [ ] Each sub-agent definition must be self-contained: complete inputs, outputs, and behavior described without relying on inherited context
- [ ] All Jira mutations go through Atlassian MCP tool calls (no direct API calls)
- [ ] Intention output must never contain solution language (no architecture, no implementation steps, no library names)
- [ ] Feature linker must stop at top-level entry points — must not recurse into feature internals
- [ ] Graceful degradation: if a sub-agent is unavailable, the master skill explains the gap and continues

---

## Tasks

### Specification Phase (this milestone)
- [x] Write master spec document

### Implementation Phase (next milestones)
- [ ] Create `generic-work-item-field-auditor` agent (self-contained, independently invokable)
- [ ] Create `generic-work-item-title-improver` agent (self-contained, independently invokable)
- [ ] Create `generic-work-item-feature-linker` agent (top-level only, self-contained)
- [ ] Create `generic-work-item-intention-writer` agent (intention-only, no solution, self-contained)
- [ ] Create `generic-work-item-preparation` master skill (orchestrator — launches all agents above)
- [ ] Test each sub-agent standalone before wiring into the master skill
- [ ] Test end-to-end with a real ticket (ticket with all fields missing)
- [ ] Test end-to-end with no ticket (intent-only mode)
- [ ] Verify intention output contains no solution language

---

## Dependencies

- `generic-jira-contributor-context` skill (already exists)
- `generic-spec` skill (already exists)
- Atlassian MCP server (must be configured in the consuming project)
- Active Jira project with accessible tickets (for ticket-mode)

---

## Success Criteria

- Given a raw Jira ticket, the workflow produces a ticket with all required fields filled, a platform-tagged title, and a fully structured description — with every change approved by the user
- Given no ticket, the workflow produces a local `projectspecs/` entry with equivalent quality
- Each sub-skill can be run standalone without the master orchestrator
- The workflow can be adopted by any project without modification

---

## Open Questions

- Should the field auditor enforce a fixed required-field list, or allow each project to configure its own list via `CLAUDE.md`?
- `generic-work-item-feature-linker`: when no local codebase is present, is Jira-only search sufficient to identify the relevant feature landscape?
- What defines the boundary between "top-level feature" and "too deep" for the feature linker? Should it be a configurable depth parameter or a fixed rule (e.g., epics only)?
- Should the master skill support a `--dry-run` mode that presents all proposed changes without writing anything to Jira?
- When does the solution design phase begin? Is it a separate master skill that takes the intention output as its input, or a continuation of this workflow in a later iteration?

## Notes

This spec drives milestone 002. Each sub-skill listed in the Tasks section will become its own skill file under `plugins/puzzle9900-claude-plugin/skills/`. The master orchestrator skill will reference all sub-skills by name using the Skill tool.

Cross-reference: milestone 001 (`generic-ai-native-engineering-framework`) established the plugin architecture that this workflow builds on.
