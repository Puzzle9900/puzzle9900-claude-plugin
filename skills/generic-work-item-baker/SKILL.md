---
name: generic-work-item-baker
description: Activates when the user says they want to start working on a Jira ticket, feature, or task. Identifies involved features, loads their context, proposes concrete work via the generic-work-item-proposal agent, then saves the agreed definition to a spec or Jira before handing off for implementation plan.
type: generic
---

# generic-work-item-baker

## Context

Use this skill when a user signals they are about to start working on something:
- "Start working on MOB-1234"
- "I want to work on adding metrics to the checkout feature"
- "Let's begin implementing the dark mode toggle"
- "Start working on this Jira ticket: [URL or key]"

The skill bridges the gap between a vague intention and a well-defined, scoped work item. It identifies what features are involved, loads their context, proposes concrete work, iterates with the user until the scope is agreed, and persists the output.

**This skill does not implement anything.** Its sole purpose is to define the work clearly — what needs to be done, why, and where — so that implementation can begin with full shared understanding. Once the work definition is saved, the skill explicitly asks the user whether to proceed to implementation.

## Steps

### 1. Extract work item intent

Parse the user's statement and identify:
- **Title**: Short name for what is being worked on (derive from the statement)
- **Description**: What the user wants to accomplish (as stated)
- **Jira ticket key**: Present if the user mentioned one (e.g., `PROJ-123`, a Jira URL)

If the description is too vague to proceed (e.g., "start working on the app"), ask one clarifying question: "What specifically do you want to accomplish?"

### 2. Resolve Jira ticket (if applicable)

If a Jira ticket key or URL was identified:
1. Fetch the ticket using `searchJiraIssuesUsingJql` with `key = PROJ-123` and `fields: ["summary", "description", "status", "assignee", "labels", "components"]`
2. Extract the ticket summary and description to enrich the work item context
3. Ask the user: **"Do you want me to update Jira as we define this work item?"** (yes/no)
   - If yes: note to update Jira at Step 6
   - If no: proceed with spec only

If no Jira ticket was mentioned, skip Jira and go directly to Step 3.

### 3. Identify involved features

Ask the user: **"Which features or areas of the codebase does this work touch?"**

Accept one of three responses:
- **User lists features** → use them, proceed to Step 4
- **User is unsure** → explore the codebase (see below)
- **User says "all of it" or is vague** → ask for the one primary feature, then explore from there

**Codebase exploration (when user is unsure):**
- Search for code related to the work item description using Grep and Glob
- Look for folder structures, module names, or file clusters matching the topic
- Propose 2-5 candidate feature areas and ask the user to confirm which apply

### 4. Load feature context

For each confirmed feature:

1. **Check for a feature expert agent**: look for `agents/*-<feature-keyword>-expert.md` in the current working directory
   - If found: note the agent path — it will be referenced in Step 5 as a context source
   - If not found: explore the codebase for that feature area:
     - Find relevant directories and key files using Glob and Grep
     - Read up to 3 representative files to understand patterns, entry points, and integration points
     - Summarize what the feature does and where its code lives

2. Compile a **feature context block** per feature:
   ```
   Feature: <name>
   Agent: agents/<name>-expert.md (if exists) | none
   Code paths: <glob patterns>
   Summary: <2-3 sentence description of what this feature does>
   ```

### 5. Propose work with the generic-work-item-proposal agent

Invoke the `generic-work-item-proposal` agent with the following prompt, passing all compiled context:

```
Work item: <title>
Description: <user's original statement>
Jira ticket: <key and summary, or "none">
Features involved:
<feature context blocks from Step 4>

Based on this context, propose specific, concrete work items that would fulfill this request. For each proposal:
- Describe exactly what would be implemented
- Reference specific files, modules, or patterns in the codebase
- Provide a brief example or scenario illustrating the expected behavior
- Flag any dependencies, risks, or open questions
```

Present the agent's proposals to the user clearly. Iterate until the user says the scope is agreed:
- If the user wants alternatives: ask the agent to propose different approaches
- If the user wants narrower scope: ask the agent to focus on a subset
- If the user wants to add scope: pass the addition back to the agent

**Do not proceed to Step 6 until the user explicitly confirms the work definition.**

### 6. Persist the agreed work definition

Once the user confirms the scope, save it using both paths below as applicable:

**Always — create a spec:**
Invoke the `generic-spec` skill to create a milestone spec. Pass the following as the spec content:
- Title: work item title
- Overview: agreed description
- Goals: each agreed proposal as a goal
- Requirements: derived from the proposals (functional) and any flagged risks (non-functional)
- Technical Approach: agent-proposed approach and relevant file paths
- Tasks: one task per concrete proposal
- Dependencies: any flagged dependencies
- Notes: Jira ticket key (if applicable), feature agent paths

**If user agreed to Jira updates (Step 2):**
Update the Jira ticket using `editJiraIssue`:
- Append to the description: a structured summary of the agreed work definition
- Do not overwrite existing description content — append under a `## Work Definition` heading

### 7. Summarize and ask about implementation

Output a final summary block:

```
Work item baked: <title>
Spec: projectspecs/<number>_<slug>/spec.md
Jira: <key updated | not applicable>

Features involved:
  - <feature name> (agent: <path | none>)

Agreed work:
  - <proposal 1>
  - <proposal 2>
  ...
```

Then ask the user explicitly:

> **"The work item is fully defined. Would you like to start implementation now, or stop here?"**

- If the user says **yes**: hand off by telling them to invoke the relevant feature expert agent(s) or begin a new session scoped to the spec. Do not begin implementation yourself.
- If the user says **no** or does not respond: stop. The spec is the deliverable.

## Constraints

- **Never implement** — this skill defines work, it does not execute it. Do not write code, modify files, or begin implementation at any point
- Do not proceed to Step 6 without explicit user confirmation of the work scope — never auto-save a draft
- Never overwrite an existing Jira description — always append under `## Work Definition`
- Always create the spec regardless of Jira status — the spec is the canonical record
- If no feature context can be found (no agent, no relevant code), state this clearly and ask the user to describe the feature before continuing
- The `generic-work-item-proposal` agent must receive all feature context compiled in Step 4 — do not pass it only the user's original statement
- Never fabricate Jira ticket content, file paths, or feature descriptions — derive everything from fetched data or codebase exploration
- If the Jira MCP is unavailable, skip Jira steps entirely and note it in the summary
- Always create files in the current working directory, never in the plugin repository
