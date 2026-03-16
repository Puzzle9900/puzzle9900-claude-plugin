---
name: generic-agent-feature-expert
description: Creates a feature expert agent file loaded with all available context about a specific feature — Jira tickets, codebase, design docs, and architecture — so it can act as the permanent co-owner of that feature across the organization.
type: generic
---

## Context

Large codebases often lose feature knowledge when engineers rotate or leave. This skill addresses that by generating a dedicated agent that acts as the permanent co-owner of a feature. The resulting agent accumulates all available context — Jira history, architecture decisions, key files, patterns, and constraints — and is crafted to auto-activate whenever work on that feature is detected in any future session.

Use this skill when:
- A new feature is being handed off or ownership is unclear
- A feature expert agent does not yet exist for a feature you are about to work on
- An existing feature agent needs to be updated with new context

## Instructions

Collect feature identity and all available context sources from the user. Pull every provided source. Request anything additional that is needed to make the agent genuinely authoritative. Then generate the agent file.

The generated agent must:
- Have a `description` field specific enough for Claude to auto-invoke it whenever that feature is mentioned or touched
- Embed all collected knowledge directly in its `## Knowledge` section
- Know how to request missing context at runtime before answering
- Act as a scope guardian: flag changes that cross feature boundaries

## Steps

### 1. Collect feature identity

Ask the user for:
- **Feature name** — the short name used in tickets and code (e.g., `incident-notifications`, `emergency-call`)
- **Domain** — `generic`, `mobile`, or `backend`
- **Platform** (if mobile or backend) — `android`, `ios`, `web`, `services`, `infrastructure`, `database`
- **One-line description** of what the feature does from an end-user perspective

Derive the agent name from these inputs following the pattern:
`<domain>-<platform?>-<feature>-expert`
(e.g., `mobile-android-incident-notifications-expert`)

### 2. Collect context sources

Ask the user to provide any combination of the following. Accept as many as available — none are strictly required, but more context produces a better agent:

| Source | What to ask for |
|--------|----------------|
| Jira tickets | Ticket keys (e.g., `MOB-51743`) — epic, stories, bugs, spikes |
| Repository | Repo URL or local path — the agent will reference key files and patterns |
| Codebase samples | Specific file paths or code snippets that illustrate the feature's implementation |
| Design / spec docs | Confluence page URLs or local spec file paths |
| Architecture notes | Any ADRs, diagrams, or free-form descriptions of design decisions |
| Known constraints | Platform limitations, performance budgets, legal/compliance restrictions |
| Related features | Other features that share code, events, or data with this one |

If the user says they have no sources yet, proceed with Step 3 to gather what is available programmatically.

### 3. Pull all provided context

For each source provided, fetch its content:

- **Jira tickets**: call `searchJiraIssuesUsingJql` with `key in (KEY-1, KEY-2, ...)` and `fields: ["*all"]`. Extract: summary, description, acceptance criteria, comments, linked issues, status history.
- **Confluence pages**: call `getConfluencePage` for each URL provided. Extract the full body.
- **Local files / codebase samples**: read each file path using the Read tool. Identify key patterns, class names, function signatures, and architectural boundaries.
- **Repository URLs**: if a GitHub URL is provided, use WebFetch to retrieve READMEs and key source files.

Summarize what was retrieved before proceeding.

### 4. Request any missing critical context

Before generating the agent, identify gaps. Ask targeted follow-up questions if any of these are unknown:

- What are the entry points to this feature (screen, API endpoint, event, notification)?
- What are the most common extension or change patterns for this feature?
- Are there known bugs, tech debt, or off-limits areas?
- Who are (or were) the human co-owners, and what did they care most about?
- What does "done" look like when extending this feature?

Ask only what is genuinely missing. Do not repeat questions already answered by the context sources.

### 5. Generate the agent file

Follow the canonical agent file structure and naming conventions defined in `generic-agent-creator-structure` exactly — including frontmatter fields, section headings, and the top-level `# <full-composite-name>` heading.

Write the agent to `agents/<agent-name>.md`.

Populate the sections as follows:

- **Identity** — Who this agent is, what feature it owns, and its mandate as permanent co-owner.
- **Knowledge** — All collected context, organized into sub-sections:
  - *Feature Overview* — End-user description of the feature. What it does, why it exists.
  - *Architecture & Key Files* — Key files, classes, modules with a one-line note on each. Include file paths where known.
  - *Jira History* — Summary of epics, major stories, and notable bugs. Include ticket keys so they can be looked up.
  - *Design Decisions* — Architectural choices that were made and why. Include ADR references if available.
  - *Patterns & Conventions* — Naming patterns, state management approach, API contracts, event names.
  - *Integration Points* — Other features, services, or systems this feature depends on or is depended upon by.
  - *Known Constraints* — Performance budgets, platform limitations, compliance requirements, off-limits areas.
  - *Open Questions & Tech Debt* — Known issues, deferred decisions, and areas of uncertainty.
- **Instructions** — Runtime behavior:
  1. **State your context** — Briefly confirm which feature you are operating on and what context you have loaded.
  2. **Request missing context** — If the user's request involves something outside your loaded knowledge, explicitly ask for it before proceeding. List exactly what you need.
  3. **Answer as the co-owner** — Respond with the depth and confidence of someone who has owned this feature for years. Reference specific files, ticket keys, and decisions by name.
  4. **Guard the scope** — If a proposed change touches code or systems outside this feature's boundary, flag it explicitly before proceeding.
  5. **Suggest, don't impose** — Propose an approach consistent with existing patterns and explain why. Offer alternatives if tradeoffs exist.
- **Output Format** — Structure responses by request type: implementation (approach, files, decisions, risks), review (pattern consistency, scope violations, improvements), questions (direct answer with references).
- **Constraints** — Never answer outside scope without flagging it; always request missing context; never invent ticket keys, file paths, or decisions; refuse requests that conflict with known constraints.

After writing the file, confirm the path to the user.

### 6. Confirm and summarize

Output:

```
Agent created: agents/<agent-name>.md

Feature:     <feature name>
Domain:      <domain> / <platform>
Context loaded:
  - Jira: <N tickets>
  - Confluence: <N pages>
  - Codebase files: <N files>
  - Architecture notes: <yes/no>

Auto-activation triggers: <list the keywords from the description field>

Next steps:
  - Run /generic-skill-tester on the agent to validate it (optional)
  - Invoke /<agent-name> to test it manually
```

## Constraints

- Always follow the agent naming convention: `<domain>-<platform?>-<feature>-expert`
- The `description` field of the generated agent must contain the feature name and enough specific keywords for Claude to auto-invoke it — never write a generic description
- Do not skip Step 4 (gap analysis) — an agent with incomplete context is worse than no agent because it gives false confidence
- Do not generate a placeholder agent with empty Knowledge sections — if no context was provided and none could be fetched, stop and tell the user what is needed before the agent can be created
- Never overwrite an existing agent file without first reading it and asking the user to confirm
- The generated agent must always include runtime context-request behavior in its Instructions — it must know how to ask for more information, not just fail silently
