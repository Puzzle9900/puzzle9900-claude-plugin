---
name: generic-jira-contributor-context
description: Pull full Jira context for a contributor — identity, team, active sprint, and ticket status breakdown. Defaults to the authenticated user.
type: generic
---

# generic-jira-contributor-context

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
Request `fields: ["*all"]` to return every field on the ticket, including all custom fields.

Set `maxResults` to 50 and `responseContentFormat` to `markdown`.

### 4. Identify the active sprint name and dates
Jira instances use different custom field IDs for sprint data — do **not** hardcode `customfield_10020`. Instead, scan all returned `customfield_*` values dynamically:

For each ticket, iterate over every field whose key starts with `customfield_`. If the value is an array of objects and at least one object has `"state": "active"`, that is the sprint field. Extract from the active sprint object:
- `name` → sprint name
- `startDate` → format as `YYYY-MM-DD`
- `endDate` → format as `YYYY-MM-DD`
- `goal` → sprint goal URL (if present)
- `boardId` → used to construct the board URL: `https://<jira-host>/jira/software/projects/<project>/boards/<boardId>`

Use the first ticket that contains an active sprint — all tickets in the same `openSprints()` query share the same sprint.

### 5. Identify the team
Scan all `customfield_*` fields for a value that looks like a team name (short string, not a sprint object or array). Common patterns:
- A string field containing a team name (e.g. `"GT Subs"`, `"Mobile Platform"`)
- Fall back to the sprint name — sprint names often include the team prefix (e.g. `GT-Subs 26.S.06`)
- Last resort: use the project name(s) from the tickets

Never invent or assume a team name.

### 6. Build the status breakdown
Group all returned tickets by their `status` field. Count tickets per status. Use the exact status names returned by Jira.

### 7. Present the full contributor snapshot

Output a single consolidated summary:

```
Contributor: <displayName> (<emailAddress>)
Team:        <team name>
Sprint:      <sprint name>  (<startDate> → <endDate>)
Sprint board: <board URL>
Sprint goal:  <goal URL>
Total tickets in sprint: N

── <Status A> (N) ──────────────────────────
  [KEY-123] <summary>  |  <priority>  |  <issuetype>
  ...

── <Status B> (N) ──────────────────────────
  [KEY-456] <summary>  |  <priority>  |  <issuetype>
  ...
```

Use the exact status names from Jira as section headers. If no tickets are found in an open sprint, say so explicitly and offer to search without the sprint filter.

---

## Constraints
- Always resolve the cloudId first — never hardcode it
- Always use `fields: ["*all"]` — never request a hardcoded custom field name for sprint data
- Detect the sprint field dynamically by scanning for a `customfield_*` array containing an object with `"state": "active"`
- Default to the authenticated user; only prompt for a name if explicitly asked or if resolution fails
- Never skip the status breakdown — it is the core output of this skill
- If `openSprints()` returns no results, retry with `sprint in openSprints() OR sprint in closedSprints() ORDER BY updated DESC` and note that no active sprint was found
- Ticket keys must always be included so the user can click through to Jira
