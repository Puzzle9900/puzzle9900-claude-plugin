# Skill Test Report: generic-jira-contributor-context

**Date:** 2026-03-16
**Iterations:** 3
**Tester:** generic-skill-tester agent

## Initial Assessment (v0)

The skill was well-structured overall. Steps 1–4, 6, and 7 were clear and solid. The specific weakness was Step 5 (team identification), which had the following problems:

- **Inverted priority order**: Sprint name prefix was listed first and labeled "(most reliable)" despite being the most fragile strategy — it depends entirely on teams naming their sprints with a recognizable prefix.
- **No check for Jira native team fields**: Jira Advanced Roadmaps and Atlas both support a structured `team` custom field that returns an object with a `name` property. This is the most reliable machine-readable source of team data and was entirely absent from the strategy list.
- **No array-form team field**: Multi-value team or group custom fields return arrays of objects with `name`. Also absent.
- **Misleading user-profile step**: A previous version may have included a user-profile lookup; the step was not present in v0 but the gap left by its absence (structured sources after custom-field objects) was visible.
- **Sprint name fallback had no safety guard**: The original sprint-prefix logic said "use the first token" if no sprint-code pattern was found — this would return `"Sprint"`, `"Q1"`, or a year as the team name in common cases.
- **Custom field heuristic was vague**: No guidance on how to distinguish team-like string values from issue type names, component names, or version labels.
- **Constraints section did not mention team extraction ordering**.

## Iteration 1

### Execution Summary
Simulated execution against a realistic Jira environment (authenticated user, active sprint, multiple tickets with `fields: ["*all"]`). Steps 1–4 executed cleanly. Step 5 attempted sprint name prefix first. With a sprint named `"Sprint 42"` or `"Q1 2026 S3"`, the original logic would return `"Sprint"` or `"Q1"` — neither is a team name. The custom field scan fallback had no structured-object check. The project name fallback worked correctly.

### Issues Found
- Strategy 1 (sprint prefix) labeled as most reliable but is most fragile
- No strategy for Jira native team field as an object with `name`
- No strategy for array-of-objects team field form
- Sprint fallback extracted generic tokens (`"Sprint"`, `"Q1"`) when no sprint-code pattern was present
- Custom field heuristic gave no exclusion rules for user objects, sprint objects, or version objects
- Constraints section had no mention of team extraction priority

### Changes Applied (v0 → v1)
- **Rewrote Step 5 entirely**: introduced 6 ordered strategies:
  1. Jira native team field — single object with `name`
  2. Jira native team field — array of objects with `name`
  3. User profile team (via lookupJiraAccountId extended profile)
  4. Custom field plain string heuristic
  5. Sprint name prefix (now an explicit fallback, not first)
  6. Project name (last resort)
- Added exclusion rules for sprint-shaped objects (with `state`/`startDate`/`endDate` keys) in strategies 1 and 2
- Removed the "(most reliable)" label from sprint name prefix
- Added a guard preventing generic tokens from being returned by the sprint fallback

## Iteration 2

### Execution Summary
Re-executed as a fresh Claude instance. Strategies 1–2 now correctly prioritize structured fields. However, new issues emerged on close inspection of the exclusion rules and on strategy 3 (user profile lookup).

### Issues Found
- **Strategy 1 and 2 would match user-shaped objects**: Jira custom fields sometimes hold user references (e.g. a "Team Lead" field). Objects with `accountId` or `displayName` must be excluded explicitly — the v1 exclusion rules only covered sprint-shaped objects.
- **Strategy 1 and 2 would match version-shaped objects**: fix version objects have `releaseDate`, `archived`, `released` keys — not excluded in v1.
- **Strategy 1 and 2 would match component-shaped objects**: project component objects have `description`, `name`, `id` — not excluded in v1.
- **Strategy 3 (user profile) was factually wrong**: `lookupJiraAccountId` is a search-by-name/email tool, not an extended profile fetcher. Calling it with an `accountId` would either fail or return search results, not team membership. This step would waste an API call and mislead Claude.
- **Constraints section had no mention of the new ordering**.

### Changes Applied (v1 → v2)
- **Expanded object exclusion rules**: added user-shaped (has `accountId` or `displayName`), version-shaped (has `releaseDate`, `archived`, or `released`), and component-shaped (has `description` alongside `name` and `id`) exclusions to strategies 1 and 2.
- **Removed the user-profile strategy (v1 strategy 3)**: eliminated the call to `lookupJiraAccountId` for profile data, which the tool does not support. Renumbered remaining strategies from 4 down to 3.
- **Added Constraints entry**: "When extracting the team name, always check structured Jira custom fields (single-object and array-of-objects forms, strategies 1 and 2 in Step 5) before attempting any string heuristic or sprint-name parsing; never treat a user-shaped, sprint-shaped, version-shaped, or component-shaped object as a team field."

## Iteration 3

### Execution Summary
Final execution focusing on edge cases:
- Sprint named `"Engineering Sprint 2026-Q1-W3"` — strategy 4 (sprint prefix) correctly found no sprint-code pattern and skipped to project name rather than returning `"Engineering"`.
- Sprint named `"BE 26.S.06"` — strategy 4 correctly returned `"BE"`.
- Custom field `{"name": "Platform", "id": "123"}` — strategy 1 correctly matched and returned `"Platform"`.
- Custom field with a user reference `{"accountId": "abc", "name": "Alice"}` — correctly excluded by user-shaped rule.
- Fix version object `{"name": "1.2.3", "id": "99", "releaseDate": "2026-06-01"}` — correctly excluded by version-shaped rule.

### Issues Found
- **Exclusion rules were not clearly scoped**: the v2 exclusion rule block said "apply across all strategies below" which was technically wrong — strategy 3 deals with plain strings, not objects. The scope needed to be restricted to strategies 1 and 2 explicitly.
- **Strategy 3 ambiguity output was vague**: the phrase "note in the output" for multi-candidate situations did not specify where or how to annotate.
- **Sprint-code pattern description lacked a concrete second example**: only one example (`26.S.06`) was shown for the dot-separator case; no hyphen-separator example was present despite the pattern allowing it.
- **Constraints entry language was slightly loose**: said "object or array form" rather than mirroring the step's own terminology.

### Changes Applied (v2 → v3)
- **Scoped exclusion rules to strategies 1 and 2 explicitly**: changed heading from "apply across all strategies below" to "apply to strategies 1 and 2 only" and moved the block to appear directly above strategy 1.
- **Concretized ambiguity annotation**: changed "note in the output that the team field was inferred" to "append `(inferred)` to the Team line in the final output" — this gives a precise, actionable instruction.
- **Added hyphen-separator example to sprint-code pattern**: added `26-03` as a second example alongside `26.S.06` so both forms of the pattern are illustrated.
- **Tightened Constraints entry**: changed "object or array form" to "single-object and array-of-objects forms, strategies 1 and 2 in Step 5" to exactly mirror the step's terminology.

## Final Assessment

**Quality:** Excellent
**Ready for use:** Yes

The team extraction logic in Step 5 was substantially improved across all three iterations. The final version follows a principled priority order: structured Jira native team fields (single-object and array form) are checked first using well-defined exclusion rules that prevent false positives from user references, sprint records, fix versions, and project components. A plain-string heuristic provides a reasonable middle ground for less structured Jira instances. Sprint name parsing is now an explicit last-before-project-name fallback with a concrete pattern guard that prevents generic tokens from being returned as team names. The Constraints section enforces the ordering. The skill is generic, project-agnostic, and handles the common edge cases reliably.
