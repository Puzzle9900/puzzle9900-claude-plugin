---
name: generic-work-item-ship
description: Use when implementation is complete and reviewed — commits all changes, pushes to origin, creates a draft PR, and runs the CodeRabbit + Dangerbot approval loop until both pass. Must be run from inside the feature worktree. Requires gh CLI.
---

# generic-work-item-ship

## Overview

Takes a completed, reviewed implementation inside a worktree and ships it: commits specific files, pushes the branch, runs a CodeRabbit pre-review, creates a draft PR with a structured body, then iterates through CodeRabbit and Dangerbot feedback until both pass. The final output is a draft PR URL ready for human review.

This skill is Phase 5 — the final step in the work item pipeline.

## When to Use

- "Ship the implementation for PROJ-123"
- "Create the PR for this branch"
- After `generic-work-item-implementation-start` has completed all areas and reviews
- Running as part of `generic-work-item-full-implementation-workflow`

**Preconditions:**
- Must be inside the feature branch worktree (created by `generic-work-item-worktree-setup`)
- Must have an Implementation Report listing the files that were created or modified
- `gh` CLI must be installed and authenticated

## Steps

### 0. Load context

Parse the argument for:
- **Jira ticket key** — used in commit message, PR title, and PR body
- **Implementation Reports** — list of files created/modified per area; passed from the previous phase or available in the session context

If no ticket key is available, ask: "What's the ticket key for this implementation? (e.g. PROJ-123)"

**Verify worktree:**
```bash
git rev-parse --git-dir
```
If the output is not `.git` (i.e. we are in a regular repo root, not a worktree), warn:
> "I'm not inside a worktree. Make sure you've run `generic-work-item-worktree-setup` and the session CWD is inside `.claude/worktrees/{name}/`."
Do not proceed until this is confirmed.

**Detect repo name:**
```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```
Store as `REPO_NAME` for the approval loop API calls.

**Detect branch:**
```bash
git branch --show-current
```
Store as `BRANCH_NAME`.

### 1. Commit

Stage only the specific files listed in the Implementation Reports:
```bash
git add {file1} {file2} ...
```

Never use `git add -A` or `git add .`.

Commit:
```bash
git commit -m "[{TICKET}] {one-line summary}"
```

The summary is derived from the ticket title — concise, action-verb, ≤72 chars after the prefix.

### 2. Push

```bash
git push -u origin {BRANCH_NAME}
```

### 3. CodeRabbit pre-review

```bash
coderabbit review --plain
```

If `coderabbit` CLI is not installed: skip this step. Note the skip in the PR body (see Step 4).

**Fix:** logic errors, correctness issues, contract violations, missing null/error handling — anything a reviewer would block on.

**Skip:** style preferences, formatting, naming conventions, minor nits — not worth a commit before the PR is open.

If significant issues are found: fix the code, commit (`[{TICKET}] fix: {description}`), push, re-run. Repeat until clean or only style findings remain.

### 4. Create draft PR

Check the diff size first:
```bash
git diff origin/{base-branch}...{BRANCH_NAME} --stat | tail -1
```
If the total exceeds ~1000 lines, warn the user:
> "This PR is {N} lines changed. Large PRs often trigger Dangerbot warnings and are harder to review. Split by area, or proceed as-is?"
Wait for the user's decision before creating.

**Autonomous mode:** skip the warning — note the line count in the PR body (`<!-- PR size: {N} lines -->`) and proceed.

Create the draft PR:
```bash
gh pr create --draft \
  --title "[{TICKET}] {brief description}" \
  --body "$(cat <<'EOF'
## Addresses

{TICKET}

## Summary

{bullet points derived from the Implementation Reports — one per area, what changed}

## Test plan

{checklist from acceptance criteria — mark items verified manually with ✅}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

If CodeRabbit pre-review was skipped, add to the body:
```
<!-- CodeRabbit pre-review skipped: coderabbit CLI not installed -->
```

Store the PR number from the output.

### 5. Approval loop

Iterate until **both** conditions are met:
- CodeRabbit state is `APPROVED`
- No unresolved Dangerbot comments

**Each iteration:**

**1.** Request a review:
```bash
gh pr comment {PR_NUMBER} --body "@coderabbitai review"
```

**2.** Wait 120 seconds.

**3.** Check CodeRabbit:
```bash
gh api repos/{REPO_NAME}/pulls/{PR_NUMBER}/reviews
```
Parse `state` from the CodeRabbit reviewer entry: `APPROVED`, `CHANGES_REQUESTED`, or pending.

**4.** Check Dangerbot:
```bash
gh api repos/{REPO_NAME}/issues/{PR_NUMBER}/comments
```
Scan for unresolved comments from the Dangerbot user. Common issues and fixes:

| Dangerbot issue | Fix |
|---|---|
| Missing `## Addresses` section | `gh pr edit {PR_NUMBER} --body "{corrected body}"` |
| PR too large (>1000 lines) | Surface to user — ask whether to split or proceed |
| Missing required labels | `gh pr edit {PR_NUMBER} --add-label "{label}"` — ask user which label if unclear |

Commit and push any changes made to fix Dangerbot issues.

**5.** Fix CodeRabbit `CHANGES_REQUESTED`:
```bash
gh api repos/{REPO_NAME}/pulls/{PR_NUMBER}/comments
```
Read each inline comment. For each issue:
- Fix the code
- Commit: `[{TICKET}] fix: {short description of fix}`
- Push

After any code changes, return to step 1.

**Loop exit:** CodeRabbit `APPROVED` + no Dangerbot unresolved comments → proceed to Step 6.

Do not stop after one loop. Keep iterating until the exit condition is met or the user explicitly says to stop.

### 6. Slack notification (conditional)

Read the Slack channel from the first available source:
1. `slack_notify_channel` field in the `.workflow` state file
2. `SLACK_NOTIFY_CHANNEL` value in the project's `CLAUDE.md`

If neither is set, skip this step silently — no error, no prompt.

If a channel is found, send a message using the `slack_send_message` MCP tool:

```
channel: {slack_notify_channel}
message:
  Draft PR ready for review 👀
  *[{TICKET}] {ticket summary}*
  {PR_URL}
```

- `{TICKET}` — the Jira ticket key (e.g. `MOB-1234`)
- `{ticket summary}` — the ticket title fetched at Step 0
- `{PR_URL}` — the full GitHub PR URL

### 7. Done

Output:
> "Draft PR ready for human review: {PR_URL}"

Present a brief summary:
- Branch pushed: `{BRANCH_NAME}`
- PR: `{PR_URL}`
- Review cycles completed: `{N}`
- Slack notified: `{channel}` (or "skipped — no channel configured")
- Any remaining non-blocking informational findings

## Constraints

- In auto or autonomous mode, do not end your response turn between steps — execute commit → push → pre-review → PR creation → approval loop in sequence without stopping; only pause at the PR size gate in pause mode
- Never use `git add -A` or `git add .` — always stage specific files listed in the Implementation Reports
- Never squash-merge — creating the draft PR is the final action; merging is a human decision
- Never stop the approval loop after one round — keep iterating until both bots pass or the user explicitly asks to stop
- `## Addresses`, `## Summary`, and `## Test plan` are required sections in the PR body — never omit them
- CodeRabbit style/formatting findings are not fix targets — skip them in both the pre-review and the approval loop
- If `gh` CLI is unavailable, stop immediately: "gh CLI is required for this skill. Install it and re-run."
- If `coderabbit` CLI is unavailable, skip Step 3 and note the gap in the PR body — do not block the workflow
- Always verify you are inside a worktree before committing — never commit from the main repo root
- Slack notification is best-effort — if the MCP tool fails or no channel is configured, log the skip and continue; never block the workflow on a notification failure
