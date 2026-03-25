# Skill Test Report: generic-jira-contributor-context

**Date:** 2026-03-13
**Iterations:** 3
**Tester:** generic-skill-tester agent

## Initial Assessment (v0)

The skill was well-structured with a clear purpose and reasonable coverage of the Jira data retrieval flow. However, several issues made it unreliable in practice:

- `getAccessibleAtlassianResources` was used only to retrieve `cloudId`, but its `url` field — required for board URL construction — was never mentioned
- Step 3 passed `responseContentFormat: "markdown"` to `searchJiraIssuesUsingJql`, which is not a supported parameter on that MCP tool call and would silently fail or error
- Step 4 labeled the sprint `goal` field as "URL" when Jira's sprint goal is a plain text string
- Step 4's board URL template referenced `<project>` but no prior step extracted the project key from the returned tickets
- Step 5's primary team detection heuristic instructed scanning custom field key names for words like "team", "squad", or "group" — this is not feasible because Jira custom field keys are opaque numeric IDs (e.g. `customfield_10032`), never human-readable labels
- No behavior was defined when `lookupJiraAccountId` returns multiple matching accounts
- The fallback JQL in Constraints did not include the `assignee` filter, so it would return all tickets in any closed sprint across the entire Jira instance
- The output template placeholder used `<emailAddress>` while Step 2 relied on a field that varies by MCP implementation

## Iteration 1

### Execution Summary
Simulated invocation as the authenticated user with no arguments. Executed all 7 steps in sequence using a realistic Jira response. The skill reached Step 7 and produced output, but several parameters and field references were incorrect or undefined.

### Issues Found
- `responseContentFormat: "markdown"` is not a valid parameter for `searchJiraIssuesUsingJql` — it was silently ignored or caused an error
- The Jira host `url` from `getAccessibleAtlassianResources` was never stored, making board URL construction impossible
- Sprint `goal` was labeled "URL" in both Step 4 and the Step 7 output template — it is plain text
- Board URL construction required a project key that was never derived from any prior step
- Team detection heuristic relied on scanning field key names, which are always opaque IDs in Jira
- No disambiguation path existed when `lookupJiraAccountId` returned multiple accounts
- Fallback JQL missing the `assignee` filter would produce irrelevant results

### Changes Applied (v0 → v1)
- **Step 1**: Added instruction to store the `url` field from `getAccessibleAtlassianResources` for use in board URL construction.
- **Step 3**: Removed `responseContentFormat: "markdown"` — it is not a supported parameter.
- **Step 4**: Corrected `goal` label from "sprint goal URL" to "sprint goal (plain text)". Updated board URL construction to derive the project key from the first returned ticket's `key` field (the segment before the `-`).
- **Step 5**: Replaced infeasible key-name scan with a value-based heuristic: collect all `customfield_*` values that are plain short strings (under 50 chars, not objects/arrays/numbers) and treat the most distinctive one as a potential team name. Added explicit note that custom field keys are opaque IDs.
- **Step 2**: Added disambiguation behavior — if `lookupJiraAccountId` returns multiple accounts, list candidates and ask the user to confirm before proceeding.
- **Constraints**: Added constraint to not pass `responseContentFormat` or other unsupported parameters. Fixed fallback JQL to include the `assignee` filter.
- **Instructions**: Updated to acknowledge that prompting the user is appropriate when the contributor is ambiguous, not only when it cannot be resolved.

## Iteration 2

### Execution Summary
Re-executed the skill as a fresh Claude instance using the v1 definition. The flow executed cleanly through Steps 1–3. Step 4 produced a board URL. Step 5 attempted team detection. The output in Step 7 was structurally correct.

### Issues Found
- Step 5.1 still had a residual issue: it said to find fields "whose key name contains words like team, squad, or group" — this was removed in v1 but a different variant crept back in the rewrite. The heuristic remained vague ("very few candidates remain"). The sprint-name-prefix approach in Step 5.2 is actually more deterministic and should be the first strategy tried.
- Step 4 board URL construction said "use any ticket's key" which could produce inconsistent results for contributors with tickets in multiple projects. It needed to specify "first returned ticket" or "most frequent project".
- The `atlassianUserInfo` call in Step 2 hardcoded `emailAddress` as the field name. Different MCP wrappers may return this field as `email`. A resilience note was needed.

### Changes Applied (v1 → v2)
- **Step 4**: Changed "any ticket's key field" to "the first returned ticket's key field", with a clarification that if tickets span multiple projects, the most frequent project key should be used.
- **Step 5**: Rewrote the heuristic order — the sprint-name prefix approach (step 5.2) is deterministic and moved to step 5.1 as the primary strategy. The custom field value scan (now step 5.2) remains as a fallback. Added explicit note that key names are opaque IDs, not human-readable labels.
- **Step 2**: Added a note that the email field may be named `emailAddress` or `email` depending on the MCP implementation, and to use whichever is present.

## Iteration 3

### Execution Summary
Executed the v2 skill focusing on edge cases: a contributor with no active sprint, a contributor whose sprint object has no `boardId`, and a contributor with tickets across multiple projects. The skill handled most cases correctly. A few polish issues remained.

### Issues Found
- Step 4 and Step 7 had no instruction for when `boardId` is absent from the sprint object — this can happen in team-managed Jira projects. Without a guard, the skill would produce a broken or incomplete board URL.
- The output template in Step 7 still showed `<emailAddress>` as a placeholder, inconsistent with the resilience note added in v2.
- The two horizontal rule (`---`) separators inside the skill body (between Instructions and Steps, and between Steps and Constraints) are formatting artifacts with no purpose in a skill file. Removing them reduces noise.
- The team detection strategy order was corrected in v2 (sprint prefix first), but the description of the sprint-code pattern was slightly different between Step 5.1 and the example — unified for consistency.
- The constraint "Do not pass `responseContentFormat` or other unsupported parameters" was too broadly worded and could be misread as prohibiting all optional parameters. Reworded to "only pass parameters explicitly supported by the MCP tool being called".

### Changes Applied (v2 → v3)
- **Step 4**: Added explicit guard — omit the board URL line if `boardId` is absent from the sprint object.
- **Step 7**: Fixed output template placeholder from `<emailAddress>` to `<email>`. Added instruction to omit the `Sprint board` line if `boardId` was not available.
- **Formatting**: Removed the two superfluous `---` horizontal rule separators from the skill body.
- **Step 5**: Tightened the sprint-code pattern description to match the example consistently.
- **Constraints**: Replaced "Do not pass `responseContentFormat` or other unsupported parameters" with "Only pass parameters explicitly supported by the MCP tool being called — do not add formatting hints or output-shaping parameters unless documented".

## Final Assessment

**Quality:** Good
**Ready for use:** Yes

The skill began as a mostly correct but brittle definition that would fail on real Jira instances due to a non-existent MCP parameter, a missing host URL extraction, an incorrectly typed sprint field, and an infeasible team detection algorithm. After three iterations, all critical correctness issues were resolved:

- The execution flow is now fully self-contained and deterministic for the common case
- Team detection now leads with the most reliable signal (sprint name prefix) rather than an impossible heuristic
- The board URL is constructed correctly and omitted gracefully when data is unavailable
- The contributor disambiguation path handles multi-match scenarios explicitly
- The fallback behavior for missing sprints is scoped correctly to the target contributor
- The output template is consistent with the data actually available from the MCP tools

The remaining area of inherent uncertainty — team name detection from custom fields — is a limitation of Jira's data model (opaque field IDs) rather than a skill deficiency. The skill now acknowledges this clearly and degrades gracefully.
