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

Use a two-step approach to avoid oversized responses:

**Step 3a — Discover the sprint field ID**: Call `searchJiraIssuesUsingJql` with `jql: "assignee = \"<accountId>\" AND sprint in openSprints()"`, `maxResults: 1`, and `fields: ["*all"]`. This small probe uses the contributor's `accountId` and discovers which `customfield_*` key holds sprint data without fetching the full ticket set.

**Step 3b — Fetch all sprint tickets with targeted fields**: Once you know the sprint field ID (e.g. `customfield_10007`), call `searchJiraIssuesUsingJql` again with:
```
assignee = "<accountId>" AND sprint in openSprints() ORDER BY status ASC
```
Request only the fields you need:
```
["summary", "status", "issuetype", "priority", "project", "<sprint_field_id>"]
```
Set `maxResults` to 50.

If Step 3a returns no tickets (no open sprint), skip Step 3b and go to Step 3c.

**Step 3c — Closed-sprint fallback**: If the `openSprints()` query returns no results, perform a two-sub-step closed-sprint probe:

1. Call `searchJiraIssuesUsingJql` with `jql: "assignee = \"<accountId>\" AND sprint in closedSprints() ORDER BY updated DESC"`, `maxResults: 1`, and `fields: ["*all"]`. This discovers the sprint field ID from a closed-sprint ticket.
2. Once the sprint field ID is known (or if it was already known from a partial Step 3a result), call again with `maxResults: 20` and the targeted fields `["summary", "status", "issuetype", "priority", "project", "<sprint_field_id>"]`.

Note in the output that no active sprint was found and the results reflect recently updated tickets from the most recent closed sprint.

If sub-step 1 also returns 0 results (no closed-sprint tickets either), output a message that no sprint tickets were found for this contributor. Skip Steps 4 and the sprint-related fields in Step 7 (Sprint, Sprint board, Sprint goal). Still attempt Steps 5 and 6 if any tickets were returned by any other means; otherwise present only the Contributor and Cloud lines and note the absence of ticket data.

### 4. Identify the active sprint name and dates
Jira instances use different custom field IDs for sprint data — do **not** hardcode `customfield_10020`. Instead, scan all returned `customfield_*` values dynamically:

For each ticket, iterate over every field whose key starts with `customfield_`. If the value is an array of objects and at least one object has a `"state"` key, that is the sprint field. When operating on open-sprint results (Steps 3a/3b), look for an object where `state = "active"`. When operating on closed-sprint results (Step 3c), look for an object where `state = "closed"` and use the one with the most recent `endDate`. Extract from the identified sprint object:
- `id` → sprint ID (integer or string; used in the output header)
- `name` → sprint name
- `startDate` → format as `YYYY-MM-DD`
- `endDate` → format as `YYYY-MM-DD`
- `goal` → sprint goal (plain text; omit this line if empty or missing)
- `boardId` → used with the project key to construct the board URL (omit the board URL line if `boardId` is absent)

To construct the board URL when `boardId` is present:
1. Take the project key from the **first returned ticket's** `key` field (the part before the `-`, e.g. `GT` from `GT-123`). If tickets span multiple projects, use the project key that appears most frequently.
2. Build: `https://<jira-host>/jira/software/projects/<projectKey>/boards/<boardId>`

Use the first ticket that contains an active sprint. In rare cases (Jira Advanced Roadmaps with nested or parallel sprints), multiple active sprint records may appear across tickets — if so, use the sprint whose `startDate` is most recent, or the sprint that appears on the greatest number of tickets.

### 5. Identify the team
Apply the following strategies in order, stopping at the first result that yields a non-empty team name. Structured data sources always take priority over heuristic or parsed sources.

**Object exclusion rules (apply to strategies 1 and 2 only):**
Before treating any object or array of objects as a team field, check the following shapes and exclude any match:
- **User-shaped**: object has an `accountId` or `displayName` key — this is a Jira user reference, not a team.
- **Sprint-shaped**: object has a `state`, `startDate`, or `endDate` key — this is a sprint record.
- **Version-shaped**: object has a `releaseDate`, `archived`, or `released` key — this is a fix version.
- **Component-shaped**: object has both a `description` key and an `id` key alongside `name` — this is a project component.

1. **Jira native team field — single object with `name`** (highest priority): scan all `customfield_*` fields on the first returned ticket. If any field's value is a non-null object that has a `name` property and does not match any excluded shape above, treat it as a team field and use its `name` value. Also capture its `id` field if present — this is the team entity ID. This covers Jira Advanced Roadmaps team assignments and Atlas team custom fields.

2. **Jira native team field — array of team objects**: if a `customfield_*` value is a non-empty array of objects where each object has a `name` property and none of the objects match any excluded shape above, use the `name` of the first object and capture its `id` field if present. This covers multi-value team or group custom fields.

3. **Custom field — plain string heuristic**: scan all `customfield_*` fields on the first returned ticket for values that are plain non-empty strings shorter than 60 characters and satisfy all of the following: not a date string (does not match `YYYY-MM-DD` or contain a `T` separator), not purely numeric, not a URL, and not a value that appears verbatim as the `status.name` of any ticket returned in Step 3b (this dynamically excludes workflow statuses such as `"To Do"`, `"In Progress"`, `"Done"`, `"Closed"`, etc. for this specific Jira instance). Among the remaining candidates, prefer a value that is title-case, contains a hyphen, or reads like an org unit name. If exactly one candidate remains, use it. If multiple candidates remain, pick the most org-unit-like value and append `(inferred)` to the Team line in the final output.

4. **Sprint name prefix** (fragile fallback): only attempt this if none of the above strategies produced a result. Parse the sprint name: if the second whitespace-separated token begins with two digits followed by a dot or hyphen (e.g. `26.S.06` or `26-03`), use the first token as the team name. Example: `GT-Subs 26.S.06` → team is `GT-Subs`. If the sprint name does not match this pattern, do not guess — skip directly to strategy 5. Never return a generic word like `"Sprint"`, `"Q1"`, or a bare year as the team name.

5. **Project name** (last resort): use the value of `fields.project.name` from the first ticket.

Never invent or assume a team name. If none of the above strategies yields a result, output `Team: unknown` and note that team data could not be detected.

### 6. Build the status breakdown
Group all returned tickets by their `status.name` field. Count tickets per status. Use the exact status names returned by Jira. If a ticket has a null or missing `status` or `status.name`, group it under the label `(no status)` rather than omitting it from the count.

### 7. Present the full contributor snapshot

Output a single consolidated summary:

```
Contributor: <displayName> (<email>)  [accountId: <accountId>]
Cloud:       <site name>  [cloudId: <cloudId>]
Team:        <team name or "unknown">  [id: <teamId>]
Sprint:      <sprint name>  (<startDate> → <endDate>)  [id: <sprintId>]
Sprint board: <board URL>  [boardId: <boardId>]
Sprint goal:  <sprint goal text>
Total tickets in sprint: N

── <Status A> (N) ──────────────────────────
  [KEY-123] <summary>  |  <priority>  |  <issuetype>
  ...

── <Status B> (N) ──────────────────────────
  [KEY-456] <summary>  |  <priority>  |  <issuetype>
  ...
```

Conditional omissions — apply before rendering the above template:
- Omit `[id: <teamId>]` if no team `id` was found
- Omit `[id: <sprintId>]` if no sprint `id` was found
- Omit the `Sprint board` line entirely if `boardId` was not available
- Omit the `Sprint goal` line entirely if the goal is empty or missing

Use the exact status names from Jira as section headers. If no tickets are found in an open sprint, say so explicitly and offer to search without the sprint filter.

## Constraints
- Always resolve the cloudId first — never hardcode it
- Always store the Jira host `url` from `getAccessibleAtlassianResources` for use in URL construction
- Always use the two-step probe approach in Step 3: a `maxResults: 1` / `fields: ["*all"]` probe first, then a targeted fields call for the full result set — never request `["*all"]` with a high `maxResults` as it produces oversized responses
- Detect the sprint field dynamically in the probe response by scanning for a `customfield_*` array containing an object with a `"state"` key; match `"active"` for open-sprint results and `"closed"` for closed-sprint results
- Default to the authenticated user; only prompt for a name if explicitly asked or if resolution fails
- If `lookupJiraAccountId` returns multiple matches, always ask the user to disambiguate before proceeding
- Never skip the status breakdown — it is the core output of this skill
- If `openSprints()` returns no results, follow the closed-sprint fallback in Step 3c — do not omit the sprint section entirely
- Ticket keys must always be included so the user can click through to Jira
- Only pass parameters explicitly supported by the MCP tool being called — do not add formatting hints or output-shaping parameters unless documented
- When extracting the team name, always check structured Jira custom fields (single-object and array-of-objects forms, strategies 1 and 2 in Step 5) before attempting any string heuristic or sprint-name parsing; never treat a user-shaped, sprint-shaped, version-shaped, or component-shaped object as a team field; always capture the `id` field alongside the `name` when a structured team field is found — omit `[id: ...]` only if no `id` is present
