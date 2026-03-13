---
name: generic-contributor-jira-context
description: Pull full Jira context for a contributor — identity, team, active sprint, and ticket status breakdown. Defaults to the authenticated user.
type: generic
---

# generic-contributor-jira-context

## Context
Use this skill to get a complete picture of a contributor's current Jira workload. It identifies who the member is, what team they belong to, which sprint they are in, and the status of every ticket assigned to them. Defaults to the currently authenticated Jira user unless another contributor is specified.

## Instructions

You are a Jira context aggregator. Call the Atlassian MCP tools in sequence to build a complete contributor snapshot. Present the result as a structured summary — do not ask the user questions unless the contributor cannot be resolved.

---

## Steps

### 1. Resolve the cloudId
Call `getAccessibleAtlassianResources` to get the `cloudId` needed for all subsequent Jira calls. Use the first resource returned unless the user has specified a site.

### 2. Identify the contributor
- **Default**: call `atlassianUserInfo` to get the authenticated user's `accountId`, `displayName`, and `emailAddress`
- **If a name or email was provided by the user**: call `lookupJiraAccountId` to resolve it to an `accountId`

### 3. Find tickets in the active sprint
Call `searchJiraIssuesUsingJql` with:
```
assignee = "<accountId>" AND sprint in openSprints() ORDER BY status ASC
```
Request these fields: `summary`, `status`, `issuetype`, `priority`, `assignee`, `project`, `sprint`, `customfield_10020` (sprint field fallback)

Set `maxResults` to 50 and `responseContentFormat` to `markdown`.

### 4. Identify the team
Jira does not always have an explicit team field. Derive the team from the results in this order:
1. Check for a `Team` or `team` custom field on the returned tickets
2. Use the **sprint name** — sprint names typically include the team name (e.g. `Mobile Team - Sprint 14`)
3. Fall back to the **project name(s)** the tickets belong to

### 5. Identify the active sprint
Extract the sprint name and sprint dates (start / end) from the ticket data. All tickets in the same `openSprints()` query share the same sprint — use the first one found.

### 6. Build the status breakdown
Group all returned tickets by their `status` field. Count tickets per status. Present as:

```
Sprint: <sprint name> (<start date> → <end date>)
Team:   <team name>

Status Breakdown:
  In Progress  (N)  — <ticket keys>
  To Do        (N)  — <ticket keys>
  In Review    (N)  — <ticket keys>
  Done         (N)  — <ticket keys>
  Blocked      (N)  — <ticket keys>
  <other>      (N)  — <ticket keys>
```

### 7. Present the full contributor snapshot

Output a single consolidated summary:

```
Contributor: <displayName> (<emailAddress>)
Team:        <team name>
Sprint:      <sprint name> (<start> → <end>)
Total tickets in sprint: N

── In Progress (N) ──────────────────────────
  [KEY-123] <summary>  |  <priority>  |  <issuetype>
  ...

── To Do (N) ────────────────────────────────
  [KEY-456] <summary>  |  <priority>  |  <issuetype>
  ...

── In Review (N) ────────────────────────────
  ...

── Done (N) ─────────────────────────────────
  ...

── Blocked / Other (N) ──────────────────────
  ...
```

If no tickets are found in an open sprint, say so explicitly and offer to search without the sprint filter.

---

## Constraints
- Always resolve the cloudId first — never hardcode it
- Default to the authenticated user; only prompt for a name if explicitly asked or if resolution fails
- Never skip the status breakdown — it is the core output of this skill
- If `openSprints()` returns no results, retry with `sprint in openSprints() OR sprint in closedSprints() ORDER BY updated DESC` and note that no active sprint was found
- Team identification must be derived from data — never invent or assume a team name
- Ticket keys must always be included so the user can click through to Jira
