# Generic Work Item — Orchestration Flow

**Type:** Reference Spec  
**Scope:** All `generic-work-item-*` skills and agents  
**Focus:** End-to-end workflow, chaining, and gates

---

## Overview

5 sequential phases, each a standalone skill. The `full-implementation-workflow` wrapper chains them with user gates.

```
                    ┌─────────────────────────────────────────────────────────────────────────┐
                    │            full-implementation-workflow  (optional wrapper)              │
                    │   resolves ticket · creates worktree (pre-flight) · reads/writes        │
                    │   .workflow state file · resumes from current_phase on restart          │
                    └──────────────────────────────┬──────────────────────────────────────────┘
                                                   │
                    ┌──────────────────────────────▼──────────────────────────────────────────┐
                    │  INPUT                                                                   │
                    │  Jira ticket key · Jira URL · plain-text description · local spec path  │
                    │  PRE-FLIGHT: worktree-setup · .workflow state file (read or create)     │
                    └──────────────────────────────┬──────────────────────────────────────────┘
                                                   │
 ╔═════════════════════════════════════════════════▼═══════════════════════════════════════════╗
 ║  PHASE 1 — Preparation                                                                      ║
 ║  skill: generic-work-item-preparation                                                       ║
 ╠═════════════════════════════════════════════════════════════════════════════════════════════╣
 ║                                                                                             ║
 ║   confirm intent  ──►  feature-linker  ──►  field-auditor  ──►  title-improver              ║
 ║        │                 ▲ user trims         ▲ user approves    ▲ user accepts             ║
 ║        │                 │ / adds             │ field changes    │ / edits                  ║
 ║        │                                                         │                          ║
 ║        └──────────────────────────────────►  intention-writer  ──┘                          ║
 ║                                                ▲ user approves                              ║
 ║                                                │ sections                                   ║
 ║                                                │                                            ║
 ║                                           final review  (user can go back to any step)      ║
 ║                                                │                                            ║
 ║                                           persist ──► editJiraIssue / createJiraIssue       ║
 ╚═════════════════════════════════════════════════════════════════════════════════════════════╝
                                                   │
                    OUTPUT: Jira ticket updated · no local files (in full workflow context)
                                                   │
 ╔═════════════════════════════════════════════════▼═══════════════════════════════════════════╗
 ║  PHASE 2 — Worktree Setup                                                                   ║
 ║  skill: generic-work-item-worktree-setup                                                    ║
 ╠═════════════════════════════════════════════════════════════════════════════════════════════╣
 ║                                                                                             ║
 ║   derive name: {type}/{ticket-key}/{summary-kebab}  (≤64 chars)                             ║
 ║       │                                                                                     ║
 ║   EnterWorktree(name)                                                                       ║
 ║       │                                                                                     ║
 ║   .claude/worktrees/{name}/ created · session CWD = worktree                               ║
 ║                                                                                             ║
 ╚═════════════════════════════════════════════════════════════════════════════════════════════╝
                                                   │
                    OUTPUT: .claude/worktrees/{name}/ created · CWD = worktree
                                                   │
 ╔═════════════════════════════════════════════════▼═══════════════════════════════════════════╗
 ║  PHASE 3 — Pre-Implementation Tech Scope                                                    ║
 ║  skill: generic-work-item-pre-implementation-tech-scope                                     ║
 ╠═════════════════════════════════════════════════════════════════════════════════════════════╣
 ║                                                                                             ║
 ║   load intent  ──►  confirm feature list (user add/remove)                                 ║
 ║                                │                                                            ║
 ║             ┌──────────────────┴──────────────────┐                                        ║
 ║             │   FOR EACH feature  ·  IN PARALLEL   │                                       ║
 ║             │                                      │                                        ║
 ║             │   feature-technical-scope agent      │                                        ║
 ║             │     read expert file (if exists)     │                                        ║
 ║             │     map feature → sub-areas          │                                        ║
 ║             │     investigate sub-areas (parallel) │                                        ║
 ║             │     → Area Impact Block              │                                        ║
 ║             └──────────────────┬──────────────────┘                                        ║
 ║                                │                                                            ║
 ║                         technical-reviewer                                                  ║
 ║                    synthesizes all Area Impact Blocks                                       ║
 ║                         → Technical Specification                                           ║
 ║                                │                                                            ║
 ║                     user approves spec  ──►  save technical-scope.md                       ║
 ╚═════════════════════════════════════════════════════════════════════════════════════════════╝
                                                   │
                           OUTPUT: technical-scope.md saved inside worktree
                                                   │
 ╔═════════════════════════════════════════════════▼═══════════════════════════════════════════╗
 ║  PHASE 4 — Implementation Start                                                             ║
 ║  skill: generic-work-item-implementation-start                                              ║
 ╠═════════════════════════════════════════════════════════════════════════════════════════════╣
 ║                                                                                             ║
 ║   impact-analyzer                                                                           ║
 ║     map files per area · identify foundation candidates · order by dependency + blast       ║
 ║     → Implementation Queue + Foundation Artifacts list                                      ║
 ║         │                                                                                   ║
 ║   user reorders / merges / excludes areas                                                   ║
 ║         │                                                                                   ║
 ║   foundation-builder                                                                        ║
 ║     shared interfaces · data models · contracts (used by 2+ areas)                         ║
 ║     → Foundation Manifest                                                                   ║
 ║         │                                                                                   ║
 ║   ┌─────▼──────────────────────────────────────────────┐                                   ║
 ║   │  code-reviewer  (scope: foundation)                 │                                   ║
 ║   │  CLEAN ──► proceed                                  │                                   ║
 ║   │  ISSUES ──► area-implementer (fix) ──► re-review   │  max 3 loops → ask user           ║
 ║   └─────┬──────────────────────────────────────────────┘                                   ║
 ║         │                                                                                   ║
 ║         │  FOR EACH area  ·  SERIALLY  (next area waits for CLEAN)                         ║
 ║         │  ┌──────────────────────────────────────────────────────────────────────┐        ║
 ║         │  │  glob for expert agent file                                          │        ║
 ║         │  │  area-implementer  (reads expert file · reads code · writes code)    │        ║
 ║         │  │    → Implementation Report                                           │        ║
 ║         │  │                                                                      │        ║
 ║         │  │  code-reviewer  (scope: area:<name>)                                 │        ║
 ║         │  │  CLEAN ──► next area                                                 │        ║
 ║         │  │  ISSUES ──► area-implementer (fix) ──► re-review  (max 3 loops)     │        ║
 ║         │  └──────────────────────────────────────────────────────────────────────┘        ║
 ║         │                                                                                   ║
 ║   ┌─────▼──────────────────────────────────────────────┐                                   ║
 ║   │  code-reviewer  (scope: full — all areas + found.)  │                                   ║
 ║   │  CLEAN ──► proceed                                  │                                   ║
 ║   │  ISSUES ──► area-implementer (fix) ──► re-review   │  max 3 loops → ask user           ║
 ║   └─────┬──────────────────────────────────────────────┘                                   ║
 ║         │                                                                                   ║
 ║         │  FOR EACH area  ·  IN PARALLEL                                                   ║
 ║         │  ┌────────────────────────────────────────────────────────────────────┐          ║
 ║         │  │  isolation-reviewer  (area files + foundation reference only)      │          ║
 ║         │  │  → isolation findings (Critical / Major)                           │          ║
 ║         │  └────────────────────────────────────────────────────────────────────┘          ║
 ║         │         │                     │                                                   ║
 ║         │   Critical ──► back to    Non-critical ──► surface to user                       ║
 ║         │               full review                  (no action)                           ║
 ║         │                                                                                   ║
 ║   implementation summary                                                                    ║
 ╚═════════════════════════════════════════════════════════════════════════════════════════════╝
                                                   │
                               OUTPUT: Implemented code · review summary
                                                   │
 ╔═════════════════════════════════════════════════▼═══════════════════════════════════════════╗
 ║  PHASE 5 — Ship                                                                             ║
 ║  skill: generic-work-item-ship                                                              ║
 ╠═════════════════════════════════════════════════════════════════════════════════════════════╣
 ║                                                                                             ║
 ║   git add {specific files}  ──►  git commit  ──►  git push                                 ║
 ║       │                                                                                     ║
 ║   coderabbit review --plain                                                                 ║
 ║   ISSUES ──► fix → commit → push → re-review                                               ║
 ║   CLEAN  ──►                                                                                ║
 ║       │                                                                                     ║
 ║   gh pr create --draft  (## Addresses · ## Summary · ## Test plan)                         ║
 ║       │                                                                                     ║
 ║   ┌─── approval loop ──────────────────────────────────────────────────────────────────┐   ║
 ║   │  @coderabbitai review → wait → check CodeRabbit + Dangerbot                        │   ║
 ║   │  Dangerbot issues → fix (labels · ## Addresses · PR size) → commit + push          │   ║
 ║   │  CodeRabbit CHANGES_REQUESTED → fix code → commit + push                           │   ║
 ║   │  CodeRabbit APPROVED + no Dangerbot issues → done                                  │   ║
 ║   └────────────────────────────────────────────────────────────────────────────────────┘   ║
 ║                                                                                             ║
 ╚═════════════════════════════════════════════════════════════════════════════════════════════╝
                                                   │
                    OUTPUT: Draft PR created · CodeRabbit + Dangerbot approved
```

---

## Key Design Constraints

- **No parallel area implementation.** Areas run serially; each must be CLEAN before the next starts.
- **Foundation before areas.** Foundation Manifest must exist before any area implementer runs.
- **No solution language in Phases 1–3.** Only capability and intent language; implementation details are banned until Phase 4.
- **Outside-in worktree model.** The worktree is created by `generic-work-item-worktree-setup` in the main repo session at `.worktrees/{name}/` — never inside `.claude/`. A new Claude session is then launched natively inside the worktree via `claude --worktree {name}`. All phases run in that session; `EnterWorktree` is never called mid-session.
- **`work_dir` is explicit.** The absolute worktree path (`pwd` at session start) is written into `.workflow` by the setup skill and passed to every phase. No phase infers its working directory from CWD — `work_dir` is always stated.
- **Session isolation.** Because the worktree session starts independently (not as a child of the main session), it has no inherited hooks, no relative-path issues, and no parent `.claude/` config cascade.
- **Full context per invocation.** Each sub-agent receives its complete context in the prompt; no shared mutable state.
- **Expert agents are supplements.** If a local `*<feature>*expert*.md` file exists, it enriches (not replaces) investigation.
- **Phases are decoupled.** Each phase can run standalone; the full-workflow wrapper is optional.
- **Atlassian auth errors are not unavailability.** Before any Jira write, verify token health (`getAccessibleAtlassianResources`). Auth failure (expired token) → pause and re-authenticate, then retry. Connection failure (server unreachable) → local-only fallback. Never silently downgrade to local-only on a 401.

---

## Agents & Their Concerns

### `generic-work-item-feature-linker`
**Purpose:** Surface 3–7 top-level features/product areas related to the work item.  
**Concerns:**
- Stays at entry-point level only — never recurses into feature internals or reads implementation files
- Sources: Jira epics/labels/components + top-level module/folder names from the codebase (if available)
- Edge case: when no Jira MCP and no codebase are present, reports what it can infer from the intent text alone
- Does NOT produce code paths, class names, or architectural notes

### `generic-work-item-field-auditor`
**Purpose:** Audit required Jira fields and propose corrected values.  
**Concerns:**
- Uses `generic-jira-contributor-context` to resolve correct assignee, team, and sprint for the authenticated user
- Never writes field changes until the user explicitly approves the full set
- Skipped entirely in intent-only mode (no Jira ticket)
- Edge case: when contributor context is unavailable, presents fields without suggested values and asks the user to fill them

### `generic-work-item-title-improver`
**Purpose:** Rewrite the ticket title to be platform-tagged, action-verbed, and ≤80 chars.  
**Concerns:**
- Must include a platform tag (`[iOS]`, `[Android]`, `[Web]`, `[Backend]`, `[Cross-Platform]`)
- Must use an action verb: Add, Fix, Migrate, Refactor, Remove, Enable — never vague nouns
- Presents original vs. proposed side-by-side with explanation
- Edge case: if the platform cannot be inferred from the ticket or intent, asks the user before proposing

### `generic-work-item-intention-writer`
**Purpose:** Produce a structured intention: problem, outcome, AC, keywords, features, out-of-scope, open questions.  
**Concerns:**
- Strictly "what and why" — zero solution language (no architecture, no library names, no implementation steps)
- AC must be behavioral ("the user can…", "the system returns…"), never implementation-level
- **Keywords section**: extract 3–10 domain/product terms (e.g. `payments`, `dark mode`) from the ticket, epic, labels, and related features. Product vocabulary only — no class names, file paths, or library names. These keywords are passed downstream as Glob/Grep seeds (Phase 3) and expert agent discovery anchors (Phase 4).
- Takes feature list from `feature-linker` as input; does not discover features itself
- Edge case: if existing Jira description already contains solution language, strips it and rewrites as capability language
- Presents draft section-by-section; user can revise any section without a full rewrite

### `generic-work-item-feature-technical-scope`
**Purpose:** Investigate one feature area and return an Area Impact Block.  
**Concerns:**
- Reads local expert agent file first (if provided) — uses it as primary source for code paths and constraints
- Maps the feature into sub-areas via Glob/Grep, then investigates each sub-area in parallel
- Reads interfaces, models, repositories, and entry points — never implementation internals
- Edge case: if a module path is not found, reports the gap explicitly rather than silently omitting it
- Does NOT produce implementation language — only capability needs, data contracts, and constraints
- Stops at the boundary of the feature; cross-cutting concerns are flagged but resolved by `technical-reviewer`

### `generic-work-item-technical-reviewer`
**Purpose:** Synthesize all Area Impact Blocks into a complete, de-duplicated Technical Specification.  
**Concerns:**
- Validates that every acceptance criterion from the intention is covered by at least one area
- Identifies cross-cutting concerns (analytics events, auth, encryption, error states) that span multiple areas
- Strips any implementation language that leaked into the Area Impact Blocks
- De-duplicates contracts and checklist items that appear in more than one block
- Edge case: if two blocks define the same contract with conflicting shapes, flags the conflict as an open technical question rather than picking one silently

### `generic-work-item-impact-analyzer`
**Purpose:** Map the blast radius of each area and produce an ordered Implementation Queue.  
**Concerns:**
- Reads existing codebase structure via Glob/Grep — does not write anything
- Identifies foundation candidates: artifacts needed by 2 or more areas
- Orders areas by dependency (upstream areas first) then by blast radius (lower risk first)
- Edge case: circular dependencies between areas are surfaced as a conflict for the user to resolve before implementation starts
- Returns an explicit "Foundation Artifacts" list alongside the queue

### `generic-work-item-foundation-builder`
**Purpose:** Create shared interfaces, data models, and contracts consumed by 2+ areas.  
**Concerns:**
- Reads codebase naming conventions before writing anything (Phase 0 read pass)
- Only creates artifacts that are shared — area-specific contracts stay in the area implementer's scope
- For existing files: targeted extension only — never modifies existing behavior or renames anything
- BLOCKER: if a naming conflict or incompatible existing artifact is detected, stops and asks the user before proceeding
- Returns a Foundation Manifest listing every file created and extended

### `generic-work-item-area-implementer`
**Purpose:** Implement a single area using foundation artifacts and (optionally) a local expert agent.  
**Concerns:**
- Reads expert agent file as a first-class resource when provided — not optional guidance
- Reads existing code in the area before writing anything
- New files: follow observed codebase conventions strictly
- Existing files: targeted edits only — no refactoring outside the stated scope
- Cross-cutting patterns (analytics, auth, error handling): follows observed codebase patterns, never invents new ones
- Does NOT write tests
- Returns an Implementation Report listing every file created and modified

### `generic-work-item-code-reviewer`
**Purpose:** Review implementation for Critical and Major issues only.  
**Concerns:**
- Accepts a `scope` parameter: `foundation`, `area:<name>`, or `full`
- `foundation` scope: checks correctness, naming consistency, and absence of accidental logic
- `area:<name>` scope: checks contract usage, no scope creep beyond the area's Technical Scope slice
- `full` scope: checks cross-area consistency, duplicate logic, and regressions introduced by combining all areas
- Style, formatting, and minor nits are explicitly out of scope — not reported
- Edge case: if the same issue appears in multiple areas, reports it once at the `full` scope level rather than duplicating per area

### `generic-work-item-isolation-reviewer`
**Purpose:** Review a single area in isolation — internal correctness, edge cases, contract adherence.  
**Concerns:**
- Read-only — never writes or modifies files
- Scoped strictly to the area's own files plus the Foundation Manifest as a reference
- Catches issues invisible at integration level: missing null checks, unhandled failure paths, edge cases in area-specific logic
- Returns findings as Critical or Major; Critical findings route back to the full review loop
- Non-critical findings are surfaced as informational only — no automatic fix triggered
- Edge case: if a finding originates from a foundation contract (not the area itself), it is flagged as a foundation concern and routed accordingly

---

## Related Skills & Agents

### Skills (entry points)

| Name | Phase | Description | Concerns |
|---|---|---|---|
| `generic-work-item-full-implementation-workflow` | Wrapper | Chains Phases 1–5. Pre-flight creates the worktree and `.workflow` state file; on resume reads the state file to skip completed phases. | `.workflow` is the only source of truth for phase state — never infer from file presence or CWD. |
| `generic-work-item-preparation` | Phase 1 | Enriches a ticket or raw intent through feature linking, field audit, title improvement, and intention writing, then persists to Jira. | All Jira mutations require explicit user approval. No local files in the full workflow context. |
| `generic-work-item-worktree-setup` | Phase 2 | Creates the feature branch worktree using `EnterWorktree` before any local files are written. | Always delegates to `EnterWorktree` — never runs `git worktree add` manually. |
| `generic-work-item-pre-implementation-tech-scope` | Phase 3 | Investigates the technical landscape and produces `technical-scope.md` inside the worktree; Jira is read-only. | Output must contain zero implementation language; source conflicts surface to the user. |
| `generic-work-item-implementation-start` | Phase 4 | Drives a Technical Scope to a reviewed implementation: foundation first, then serial area loop with review gates. | Hard-stops without a Technical Scope; no tests are produced at any stage. |
| `generic-work-item-area-implementer` | Phase 4 (per-area) | Implements a single area using foundation artifacts and an optional expert agent file. | Targeted edits only — no refactoring outside scope, no tests. |
| `generic-work-item-ship` | Phase 5 | Commits, pushes, creates a draft PR, and runs the CodeRabbit + Dangerbot approval loop until both pass. | Never uses `git add -A`; never squash-merges; approval loop runs until both bots pass. |

### Agents (invoked by skills)

| Name | Invoked In | Description | Concerns |
|---|---|---|---|
| `generic-work-item-feature-linker` | Phase 1 | Surfaces 3–7 top-level features related to the work item; entry points only, no deep dives. | Must not recurse into feature internals or read implementation files. |
| `generic-work-item-field-auditor` | Phase 1 | Audits required Jira fields and proposes corrected values using contributor context. | Never writes until the user approves; skipped entirely in intent-only mode. |
| `generic-work-item-title-improver` | Phase 1 | Rewrites the title with a platform tag, an action verb, and a max of 80 characters. | Asks the user before proposing if the platform cannot be inferred. |
| `generic-work-item-intention-writer` | Phase 1 | Produces the structured intention: problem, outcome, AC, features, out-of-scope — no solution language. | AC must be behavioral; strips solution language from any existing description. |
| `generic-work-item-feature-technical-scope` | Phase 3 — per feature, parallel | Investigates a feature area via sub-area divide-and-conquer, returning an Area Impact Block. | Reports module-not-found gaps explicitly; flags cross-cutting concerns for the reviewer. |
| `generic-work-item-technical-reviewer` | Phase 3 — synthesis | Synthesizes all Area Impact Blocks into a de-duplicated Technical Specification. | Every AC must map to an area; conflicting contracts become open questions, never silent choices. |
| `generic-work-item-impact-analyzer` | Phase 4 | Maps blast radius per area and returns an ordered Implementation Queue; read-only. | Circular dependencies surface as user-facing conflicts before implementation starts. |
| `generic-work-item-foundation-builder` | Phase 4 | Creates shared interfaces, data models, and contracts needed by 2+ areas. | Naming conflicts trigger a hard stop; area-specific contracts are out of scope. |
| `generic-work-item-code-reviewer` | Phase 4 — foundation · area · full | Reviews Critical and Major issues only across three scopes: foundation, area, or full. | Style and minor nits are excluded; duplicate cross-area issues are reported once at full scope. |
| `generic-work-item-isolation-reviewer` | Phase 4 — per area, parallel | Reviews one area in isolation for internal correctness and edge cases; read-only. | Critical findings route back to the full review loop; non-critical are informational only. |

### Phase Detail Specs

- [Phase 1 — Preparation](phase-1-preparation.md)
- [Phase 2 — Worktree Setup](phase-2-worktree-setup.md)
- [Phase 3 — Pre-Implementation Tech Scope](phase-3-tech-scope.md)
- [Phase 4 — Implementation Start](phase-4-implementation.md)
- [Phase 5 — Ship](phase-5-ship.md)

---

## Invocation Map

See [invocation_map.md](invocation_map.md) for the full call tree.
