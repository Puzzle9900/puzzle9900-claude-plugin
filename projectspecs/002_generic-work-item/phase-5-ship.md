# Generic Work Item Ship

**Milestone**: 002_generic-work-item-ship
**Created**: 2026-04-08
**Status**: Draft

## Overview

Takes a completed, reviewed implementation inside a worktree through a pre-push quality gate (ktlintFormat, tests, install+verify, local reviews), ships it as a draft PR, then monitors CI and bot feedback until everything is green. Final output: green draft PR + Slack notification to the user's personal channel.

This skill is the fifth and final step in the work item pipeline:

```
generic-work-item-preparation
  → (clean intention, Jira updated)
generic-work-item-worktree-setup
  → (worktree created, CWD = feature branch)
generic-work-item-pre-implementation-tech-scope
  → (technical scope: areas, contracts, checklist)
generic-work-item-implementation-start
  → (implemented solution, reviewed and verified)
generic-work-item-ship   ← this milestone
  → (draft PR, approved)
```

No tests are produced. No merging happens — this skill creates the draft PR only; merging is a human action.

---

## Workflow

```
User invokes skill with ticket key and repo context
        │
        ▼
Step 1: Format code
  ./gradlew ktlintFormat → stage formatter changes
        │
        ▼
Step 2: Run tests
  ./gradlew test
  FAILING → fix → re-run (do not proceed until green)
        │
        ▼
Step 3: Build and install
  ./gradlew installDebug (build must succeed)
        │
        ▼
Step 4: Local reviews (critical + major only)
  4a. generic-work-item-code-reviewer (scope: full)
  4b. coderabbit review --plain (local — fix logic/correctness; skip style)
        │
        ▼
Step 5: Commit
  git add {specific files — never git add -A}
  git commit -m "[{TICKET}] {summary}"
        │
        ▼
Step 6: Push
  git push -u origin {branch-name}
        │
        ▼
Step 7: Create draft PR
  gh pr create --draft --label "ai-managed-pr" (## Addresses · ## Summary · ## Test plan)
        │
        ▼
Step 8: CI + bot tracking loop (NO @coderabbitai trigger — bots run naturally)
  loop:
    - gh pr checks → fix any failing CI check → commit + push
    - gh api pulls/{pr}/reviews + comments → evaluate CodeRabbit findings
      → fix genuine issues; skip style/naming/subjective
    - gh api issues/{pr}/comments → fix Dangerbot issues
    until: CI green + no blocking issues
        │
        ▼
Step 9: Slack notification → user's personal channel (ticket, summary, worktree, PR URL, status)
        │
        ▼
Step 10: Done — "Draft PR ready for human review: {PR URL}"
```

---

## Goals

- Commit and ship all implementation artifacts in the worktree to a draft PR
- Ensure the PR passes both CodeRabbit review and Dangerbot checks before handing off
- Keep the PR body structured so Dangerbot requirements are satisfied from the first creation

---

## PR Body Structure

```markdown
## Addresses

{TICKET}

## Summary

{bullet points derived from Implementation Reports}

## Test plan

{checklist from acceptance criteria — mark items verified manually with ✅}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

The `## Addresses` section is mandatory for Dangerbot. The `## Test plan` section must map to the acceptance criteria from the ticket.

---

## Requirements

### Functional Requirements

- [ ] Stage only specific files from the Implementation Reports — never `git add -A` or `git add .`
- [ ] Commit with format `[{TICKET}] {summary}`
- [ ] Push to `origin` with `-u` flag to track the branch
- [ ] Run `coderabbit review --plain` before PR creation; fix significant issues (logic, correctness) and commit; skip style issues
- [ ] Create a draft PR using `gh pr create --draft` with the canonical body structure
- [ ] Start the approval loop immediately after PR creation
- [ ] Fix Dangerbot comments: missing `## Addresses`, missing labels, PR too large (>1000 lines)
- [ ] Fix CodeRabbit `CHANGES_REQUESTED`: read inline comments via `gh api`, fix each issue, commit + push
- [ ] Loop until CodeRabbit APPROVED and Dangerbot has no unresolved comments
- [ ] If PR exceeds ~1000 lines, surface to the user and ask whether to split before creating

### Non-Functional Requirements

- [ ] Fully generic — no hardcoded repo names, team names, or CI configurations
- [ ] Never squash-merge — create the draft PR only; merging is a human action
- [ ] If `coderabbit` CLI is not installed, skip Step 3 and note the gap in the PR body
- [ ] Do not stop after one approval loop round — keep iterating until both bots pass or the user intervenes

---

## Dangerbot Common Issues

| Issue | Fix |
|---|---|
| Missing `## Addresses` section | Add `## Addresses\n{TICKET}` to PR body via `gh pr edit --body` |
| PR too large (>1000 lines) | Surface to user before creating — suggest splitting areas into separate PRs |
| Missing labels | `gh pr edit --add-label {label}` — ask user which label if unclear |

---

## Tasks

### Specification Phase (this milestone)
- [x] Write phase spec document

### Implementation Phase
- [ ] Create `generic-work-item-ship` skill
- [ ] Test: commit + push from worktree with specific file staging
- [ ] Test: PR creation with correct body structure (Addresses + Summary + Test plan)
- [ ] Test: Dangerbot missing Addresses → auto-fix → re-check
- [ ] Test: CodeRabbit CHANGES_REQUESTED → fix → re-request → APPROVED
- [ ] Test: PR > 1000 lines → user warning before creation
- [ ] Test: `coderabbit` CLI not installed → graceful skip with PR body note

---

## Dependencies

- `004_generic-work-item-implementation-start` (Phase 4) — upstream; produces the Implementation Reports with file lists
- `002_generic-work-item-worktree-setup` (Phase 2) — upstream; establishes the branch this skill commits and pushes from
- `gh` CLI — required for PR creation and review checks
- `coderabbit` CLI — used for pre-review; skill degrades gracefully if not installed
- CodeRabbit bot — must be configured on the target repository
- Dangerbot — must be configured on the target repository; absence is handled gracefully

---

## Success Criteria

- All implementation files are committed and pushed to the feature branch
- A draft PR is created with the canonical body structure
- The PR passes CodeRabbit review (APPROVED) and Dangerbot has no unresolved comments before the skill exits
- The skill does not stop after one round — it loops until both bots pass
- No test files are created; no merging happens

---

## Open Questions

- When CodeRabbit requests changes that require significant logic fixes in the approval loop, should the skill re-run the full solution reviewer (Phase 4) or treat the fix as a targeted edit here?
- Should the PR title include the issue type tag (e.g. `[Bug][MOB-1234]` vs `[MOB-1234]`)?
- Should the skill support uploading screenshots to GitHub if `gh-upload-image.py` is available? Screenshots are not generated by the workflow but the user may have taken them manually.
