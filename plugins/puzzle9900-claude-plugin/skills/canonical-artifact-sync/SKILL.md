---
name: canonical-artifact-sync
description: Use after any meaningful change (code ship, spec close, milestone land, merge, rule tightening) to sweep every canonical artifact (agent files, specs, CLAUDE.md, cross-linked docs) for stale claims and reconcile them in the same iteration as the change. Enforces the "update-the-map-as-you-change-the-territory" discipline so no agent/spec/rule is left pointing at a world that no longer exists.
type: generic
---

# canonical-artifact-sync

## Context

Canonical artifacts — agent files (`.claude/agents/*.md`), specs (`project_specs/*/spec.md`), project rules (`CLAUDE.md`), and cross-referenced docs — accumulate stale claims fast. A behavior gets removed, a rule gets tightened, a manager stops owning a scope, a button disappears — and every file that referenced the old truth is now lying. If reconciliation is deferred, it never happens: the next session reads the stale file as authoritative and compounds the drift.

This skill codifies the reflex of sweeping those artifacts in the **same iteration** as the change, not as a separate cleanup task later. It replaces "I'll note it and fix it next time" with a concrete checklist and dispatch protocol.

Use this skill when:
- A milestone, feature, or spec just shipped (commit landed)
- A rule in `CLAUDE.md` was tightened, added, or relaxed
- A behavior was removed (dev option, button, code path, migration)
- A new canonical owner was created (new agent, new spec, new data source)
- A spec was closed or marked deferred
- The user says "close spec", "mark done", "wrap this up", "after merging"

## Instructions

When invoked, run the sync checklist below against the just-landed change. For each affected artifact class, pick the correct action (tiny-fix inline vs. background sub-agent) and dispatch. Independent sub-agents go in the **same message**, in parallel.

Read diffs and agent file contents directly — never trust a sub-agent summary over the file itself.

## Steps

### 1. Summarize the change in one paragraph

State what actually changed in the world: the removed behavior, the new rule, the renamed artifact, the closed spec. If you cannot state it in one paragraph, stop and ask the user to narrow scope — sync over a sprawling change will miss things.

### 2. Build the candidate artifact list

Identify every artifact that *might* be stale. Walk these classes in order:

| Class | How to find candidates |
|-------|------------------------|
| Agent files | `ls .claude/agents/` and flag any whose name/description overlaps the change domain |
| Specs | `ls project_specs/` — current spec, and any specs cited by `depends-on` / `see-also` |
| `CLAUDE.md` | Always check — rule changes, new constraints, updated validation commands |
| Cross-linked docs | Anything the commit message, spec, or agent file points to via path or URL |
| Other agent files | Agents that "see also" the changed artifact (graph-walk one hop) |

Output the candidate list before doing anything else. The user reviews it implicitly by the subsequent actions.

### 3. For each candidate, run the staleness question

Ask one specific question per artifact. Examples of the right shape:

- "Does this agent's section N still describe the code that shipped?"
- "Does the spec's Non-Goals list still exclude what the spec now includes?"
- "Does the `CLAUDE.md` rule reference a file path that still exists?"
- "Does the 'see also' link still resolve to an artifact with the matching topic?"

If the answer is **yes, still accurate**, skip. If **no**, go to step 4.

### 4. Pick the dispatch lane

For each stale artifact, classify:

| Lane | When | Who does it |
|------|------|-------------|
| Tiny stale-claim fix | Single phrase, single factual reconciliation, scope-limited to one section | Main thread edits inline |
| Background sub-agent | Anything broader: multiple sections, rewrites, new tables, genericization of rules | Sub-agent via Task tool |

**Tiny-fix carve-out**: The standing rule is "do not modify agent files directly from the main thread." The single exception is a small factual reconciliation — e.g., "two frozen buttons" → "no routing UI" where the phrase is wrong and the fix is surgical. Anything requiring judgement about new content, structural reorganization, or rewording across sections goes to a sub-agent.

### 5. Write the sub-agent prompts (and dispatch in parallel)

For each sub-agent, write a prompt that contains:

- **Scope**: exactly which file(s) it may edit. Name the anchors (section numbers, headings) it may touch.
- **Constraints**: "do not modify code", "do not add feature-specific examples to a generic rules section", "keep changes surgical", etc.
- **Forbidden drift**: list phrases, feature names, or specifics the sub-agent must NOT introduce. Sub-agents over-specify by default; name the trap explicitly.
- **Verification hook**: tell the sub-agent to report back the diff it produced, not a summary.

If multiple sub-agents are independent (different files, different concerns), send them in the **same tool-call batch**. They run in parallel.

### 6. Verify every sub-agent output before trusting it

When the sub-agent returns:

1. Read the actual file — never rely on the sub-agent's summary alone.
2. Grep for forbidden drift you named in step 5 (`grep -n "<feature-name>" <file>` to catch specifics that leaked into a generic section).
3. Confirm scope: the sub-agent edited only the sections you permitted.
4. If the output is wrong in any of the above, issue a corrective follow-up prompt with the specific phrases to strip or sections to re-genericize. Do not accept the output and move on.

### 7. Check the rules-over-convenience list

Independent of the specific change, scan the diff one more time against the recurring violations. One-sentence test for each:

| Rule | One-sentence test |
|------|-------------------|
| Manager/Repository/UseCase owns no scope | Does any new class instantiate `CoroutineScope(SupervisorJob() + Dispatchers.X)`? |
| No dispatcher wrapping in use cases/managers | Is there a `withContext(Dispatchers.IO)` / `flowOn(Dispatchers.IO)` around a call to a Retrofit/Room suspend function? |
| Single UiState per ViewModel | Does any ViewModel expose more than one `StateFlow`? |
| In-memory caches live in data layer | Does any manager hold an `LruCache`, `LinkedHashMap` of domain models, or similar? |
| No raw strings in Composables | Does any new Composable contain a user-facing string literal instead of `stringResource(R.string.xxx)`? |
| Feature specifics stay out of generic artifacts | Does a generic agent's rules section name a specific feature, spec number, or file path that belongs only in a feature-specific agent? |
| No `runBlocking` / `delay()` in production | Either appears anywhere outside tests? |

If any test fails, either fix inline (code) or raise it with the user before closing the sync.

### 8. Record the decision trail

Every non-trivial decision lands in exactly one durable place. Pick:

- **Spec Decisions block** — for feature-level architectural choices with rationale
- **Commit message body** — for the "why" behind the code change (primary content, not the "what")
- **Agent Historical Decisions table** — for reversed earlier positions, so the wrong answer is not rediscovered
- **`CLAUDE.md` rule** — only when the rule is universal (project-wide, not feature-scoped)

If a decision has no home, it is lost. Force the placement before closing the sync.

### 9. Cross-link the new state

When a new canonical artifact was created (new agent, new spec, new doc), walk one hop out and add reciprocal links:

- New agent → add "see also" from related existing agents
- New spec → add `depends-on` / `see-also` from/to related specs
- New rule in `CLAUDE.md` → commit message body cites the rule; spec Decisions block cites the rule

The graph stays connected. A reader landing on any node can reach any related node in one hop.

### 10. Report the sync pass

Close the sync with a short report:
- Artifacts swept: N
- Artifacts updated inline (tiny fix): N
- Artifacts updated via sub-agent: N
- Rules-over-convenience violations found: N (with list)
- Decisions recorded (where): list

The report is concrete. If any item is "deferred", name the specific reason and the follow-up.

## Worked Example

Scenario: a milestone removes a set of developer-options buttons, and the main thread has just committed the deletion.

1. **Summarize**: "Removed the two frozen developer-options buttons; the screen now has no feature-specific UI."
2. **Candidates**: feature-specific agent file (had a frozen-section referencing two buttons), developer-options agent (might list the buttons), the feature spec (might have a Non-Goals entry), `CLAUDE.md` (no rule change).
3. **Staleness**: feature-specific agent §N says "two frozen buttons" — stale. Developer-options agent has a neutral description — fine. Spec Non-Goals unchanged — fine.
4. **Dispatch**: tiny-fix lane for the agent — single phrase reconciliation, inline edit permitted.
5. **Verify**: re-read the section, confirm the zero-button state is now reflected and no other text was touched.
6. **Rules check**: no code rules triggered by a UI-only removal.
7. **Decision trail**: commit message body explains why the buttons were removed.
8. **Cross-link**: no new artifact created; nothing to link.
9. **Report**: 1 artifact swept, 1 inline fix, 0 sub-agents, 0 rule violations.

Second scenario: a new rule is introduced in a spec ("manager-only observer until a non-feature consumer exists").

1. **Summarize**: "Spec introduces a scope-boundary rule: managers observe directly; coordinator extensions wait until a second consumer appears."
2. **Candidates**: the coordinator-expert agent (generic rules section), the feature-specific agent (should cite the spec, not restate the generic rule), `CLAUDE.md` (candidate for universal rule).
3. **Staleness**: coordinator agent lacks the generic rule — stale. Feature agent correctly cites the spec — fine.
4. **Dispatch**: background sub-agent for the coordinator agent — it's a new rules subsection with cross-referenced phrasing.
5. **Sub-agent prompt** explicitly forbids naming the originating feature inside the coordinator agent's rules section.
6. **Verify**: read the file; `grep` for the feature name in the rules section; if found, issue a corrective prompt to strip specifics and re-genericize.
7. **Rules check**: no code diff to check.
8. **Decision trail**: spec Decisions block carries the rule with rationale; coordinator agent Historical Decisions gains a row; `CLAUDE.md` gets the rule only if genuinely universal.
9. **Cross-link**: coordinator agent "see also" → the spec; spec depends-on already correct.
10. **Report**: 1 artifact swept, 1 sub-agent, 1 corrective follow-up, 0 code rule violations.

Third scenario: a new config-domain was introduced (env vars for a new external service) that crosses build scripts, CI workflows, and local dev setup.

1. **Summarize**: "New env-var domain introduced; resolution pattern (env → local.properties → fallback) now covers multiple values."
2. **Candidates**: no existing agent owns this domain in full — this is the signal to create a new canonical owner.
3. **Action**: spawn a background sub-agent to create a brand-new domain-expert agent file whose single job is to own this class of change going forward.
4. **Cross-link**: existing related agents gain a "see also" to the new agent; `CLAUDE.md` gains a pointer if any rule is universal.
5. **Report**: 1 new artifact, N existing artifacts cross-linked.

## Constraints

- Never defer a sync to "next session" — either close it in the same iteration as the change, or write a durable follow-up (spec entry, ticket) that names the specific artifact and the specific staleness.
- Sub-agents execute; sub-agents do not decide. The main thread reads the diff, chooses the action, writes the prompt, verifies the output.
- Never accept a sub-agent's summary in place of reading the edited file.
- Never let a sub-agent add feature-specific content to a generic rules section. Name the trap in the prompt.
- The tiny-fix carve-out is single-phrase factual reconciliation only — anything broader goes to a sub-agent.
- Independent sub-agents go in the same message (parallel dispatch), not sequentially.
- Every decision lands in exactly one durable place (spec, commit body, agent Historical Decisions, or `CLAUDE.md`). A decision with no home is lost.
- Rules-over-convenience is not optional — the scan runs on every sync, even when the change looks UI-only.
- Do not fabricate rules or patterns that do not exist in the project's `CLAUDE.md`, spec conventions, or existing agent structure. If a candidate rule has no precedent, raise it with the user before adding it.
