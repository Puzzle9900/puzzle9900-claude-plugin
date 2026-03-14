---
name: generic-jira-contributor-context
description: Pull full Jira context for a contributor — identity, team, active sprint, and ticket status breakdown. Defaults to the authenticated user.
type: generic
---

# generic-jira-contributor-context

## Context
Use this skill to get a complete picture of a contributor's current Jira workload. It identifies who the member is, what team they belong to, which sprint they are in, and the status of every ticket assigned to them. Defaults to the currently authenticated Jira user unless another contributor is specified.

## Instructions

You are a Jira context aggregator. Call the Atlassian MCP tools in sequence to build a complete contributor snapshot. Present the result as a structured summary — do not ask the user questions unless the contributor cannot be resolved or is ambiguous.

## Steps

### 1. Resolve the cloudId and Jira host
Call `getAccessibleAtlassianResources` to get the `cloudId` needed for all subsequent Jira calls. Use the first resource returned unless the user has specified a site. Also store the `url` field from the same resource — this is the Jira host (e.g. `https://myorg.atlassian.net`) used to construct board and ticket URLs.

### 2. Identify the contributor
- **Default**: call `atlassianUserInfo` to get the authenticated user's `accountId`, `displayName`, and email address (the field may be named `emailAddress` or `email` depending on the MCP implementation — use whichever is present)
- **If a name or email was provided by the user**: call `lookupJiraAccountId` to resolve it to an `accountId`. If multiple accounts match, list the candidates (name + email) and ask the user to confirm which one to use before proceeding.

### 3. Find tickets in the active sprint
Call `searchJiraIssuesUsingJql` with:
```
assignee = "<accountId>" AND sprint in openSprints() ORDER BY status ASC
```
Request `fields: ["*all"]` to return every field on the ticket, including all custom fields.

Set `maxResults` to 50.

### 4. Identify the active sprint name and dates
Jira instances use different custom field IDs for sprint data — do **not** hardcode `customfield_10020`. Instead, scan all returned `customfield_*` values dynamically:

For each ticket, iterate over every field whose key starts with `customfield_`. If the value is an array of objects and at least one object has `"state": "active"`, that is the sprint field. Extract from the active sprint object:
- `name` → sprint name
- `startDate` → format as `YYYY-MM-DD`
- `endDate` → format as `YYYY-MM-DD`
- `goal` → sprint goal (plain text; omit this line if empty or missing)
- `boardId` → used with the project key to construct the board URL (omit the board URL line if `boardId` is absent)

To construct the board URL when `boardId` is present:
1. Take the project key from the **first returned ticket's** `key` field (the part before the `-`, e.g. `GT` from `GT-123`). If tickets span multiple projects, use the project key that appears most frequently.
2. Build: `https://<jira-host>/jira/software/projects/<projectKey>/boards/<boardId>`

Use the first ticket that contains an active sprint — all tickets in the same `openSprints()` query share the same sprint.

### 5. Identify the team
Apply the following strategy in order, stopping at the first result:

1. **Sprint name prefix** (most reliable): extract the team prefix from the sprint name. Sprint names often follow the pattern `<TeamPrefix> <SprintCode>` (e.g. `GT-Subs 26.S.06` → team is `GT-Subs`). Use the segment before the first whitespace character that is followed by a sprint-code-like pattern (`\d{2}\.`). If the sprint name contains no such pattern but has multiple space-separated tokens, use the first token.
2. **Custom field scan** (heuristic): scan all `customfield_*` fields across the first ticket for values that are plain short strings (not objects, arrays, or numbers, and fewer than 50 characters). Note that Jira custom field keys are opaque IDs (e.g. `customfield_10032`) — do not rely on key names. If a single short-string custom field stands out as organizational (e.g. title-case, contains a hyphen, does not look like a date or status), use it.
3. **Project name** (last resort): use the value of `fields.project.name` from the first ticket.

Never invent or assume a team name. If none of the above strategies yields a result, output `Team: unknown` and note that team data could not be detected.

### 6. Build the status breakdown
Group all returned tickets by their `status.name` field. Count tickets per status. Use the exact status names returned by Jira.

### 7. Present the full contributor snapshot

Output a single consolidated summary:

```
Contributor: <displayName> (<email>)
Team:        <team name or "unknown">
Sprint:      <sprint name>  (<startDate> → <endDate>)
Sprint board: <board URL>
Sprint goal:  <sprint goal text>
Total tickets in sprint: N

── <Status A> (N) ──────────────────────────
  [KEY-123] <summary>  |  <priority>  |  <issuetype>
  ...

── <Status B> (N) ──────────────────────────
  [KEY-456] <summary>  |  <priority>  |  <issuetype>
  ...
```

Omit the `Sprint board` line if `boardId` was not available. Omit the `Sprint goal` line if the goal is empty or missing. Use the exact status names from Jira as section headers. If no tickets are found in an open sprint, say so explicitly and offer to search without the sprint filter.

## Constraints
- Always resolve the cloudId first — never hardcode it
- Always store the Jira host `url` from `getAccessibleAtlassianResources` for use in URL construction
- Always use `fields: ["*all"]` — never request a hardcoded custom field name for sprint data
- Detect the sprint field dynamically by scanning for a `customfield_*` array containing an object with `"state": "active"`
- Default to the authenticated user; only prompt for a name if explicitly asked or if resolution fails
- If `lookupJiraAccountId` returns multiple matches, always ask the user to disambiguate before proceeding
- Never skip the status breakdown — it is the core output of this skill
- If `openSprints()` returns no results, retry with `assignee = "<accountId>" AND sprint in closedSprints() ORDER BY updated DESC` limited to `maxResults: 20`, and note that no active sprint was found
- Ticket keys must always be included so the user can click through to Jira
- Only pass parameters explicitly supported by the MCP tool being called — do not add formatting hints or output-shaping parameters unless documented
