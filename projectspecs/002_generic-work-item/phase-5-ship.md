# Generic Work Item Ship

**Milestone**: 002_generic-work-item-ship
**Created**: 2026-04-08
**Status**: Draft

## Overview

Takes a completed, reviewed implementation inside a worktree and ships it: commits all changes, pushes the branch, creates a draft PR, and runs the CodeRabbit + Dangerbot approval loop until both pass.

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
Step 1: Commit
  git add {specific files from Implementation Reports — never git add -A}
  git commit -m "[{TICKET}] {summary}"
        │
        ▼
Step 2: Push
  git push -u origin {branch-name}
        │
        ▼
Step 3: CodeRabbit pre-review
  coderabbit review --plain
  SIGNIFICANT ISSUES (logic, correctness) → fix → commit → push → re-run
  STYLE ONLY or CLEAN → continue
        │
        ▼
Step 4: Create draft PR
  gh pr create --draft \
    --title "[{TICKET}] {brief description}" \
    --body "## Addresses\n{TICKET}\n\n## Summary\n{bullets}\n\n## Test plan\n{AC checklist}"
        │
        ▼
Step 5: Approval loop
  loop:
    1. gh pr comment {pr} --body "@coderabbitai review"
    2. wait ~120s
    3. check:
       - gh api repos/{REPO}/pulls/{pr}/reviews          (CodeRabbit)
       - gh api repos/{REPO}/issues/{pr}/comments        (Dangerbot)
    4. fix Dangerbot issues → commit + push
    5. fix CodeRabbit CHANGES_REQUESTED → commit + push
    if CodeRabbit APPROVED and no Dangerbot issues → done
    else → go to 1
        │
        ▼
Step 6: Done
  "Draft PR ready for human review: {PR URL}"
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
