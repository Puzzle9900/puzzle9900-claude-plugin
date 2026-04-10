---
name: generic-work-item-ship
description: Use when implementation is complete and reviewed — formats code, runs tests, installs the app, runs local reviews, commits, pushes, creates a draft PR, then tracks CI and bot comments until everything is green. Must be run from inside the feature worktree. Requires gh CLI.
---

# generic-work-item-ship

## Overview

Takes a completed, reviewed implementation inside a worktree through a full pre-push quality gate, ships it as a draft PR, then monitors CI and bot feedback until the PR is green. The final output is a green draft PR with a Slack notification sent to the user's personal channel.

This skill is Phase 5 — the final step in the work item pipeline.

## When to Use

- "Ship the implementation for PROJ-123"
- "Create the PR for this branch"
- After `generic-work-item-implementation-start` has completed all areas and reviews

**Preconditions:**
- Must be inside the feature branch worktree
- Must have an Implementation Report listing the files that were created or modified
- `gh` CLI must be installed and authenticated

## Mode

Resolve `mode` from the caller, `.workflow` state file, or default to `auto`.

**autonomous** — skip all confirmation gates; proceed end-to-end without stopping
**auto** — stop only at genuine decision gates
**pause** — stop after every step

## Steps

### 0. Load context

Parse: Jira ticket key, Implementation Reports (files created/modified per area).

```bash
git rev-parse --git-dir          # verify inside worktree
gh repo view --json nameWithOwner -q .nameWithOwner  # → REPO_NAME
git branch --show-current        # → BRANCH_NAME
git rev-parse --show-toplevel    # → REPO_ROOT (for gradlew) and WORK_TREE path
```

---

### 1. Format code

```bash
cd {REPO_ROOT} && ./gradlew ktlintFormat
```

Stage all files modified by the formatter:
```bash
git diff --name-only
```

If `ktlintFormat` fails: fix the reported issues, re-run until clean.

---

### 2. Run unit tests

```bash
cd {REPO_ROOT} && ./gradlew testDebugUnitTest
```

Unit tests only — do not run integration or automation tests.

If any tests fail:
- Read the failure output
- Fix the failing tests or the code causing them
- Re-run until all tests pass

**Do not proceed to Step 3 until unit tests are passing.**

---

### 3. Build and install the app

```bash
cd {REPO_ROOT} && ./gradlew installDebug
```

If the build fails: read the error, fix it, rebuild until the install succeeds.

**Do not proceed to Step 4 until `installDebug` completes without error.**

---

### 4. Local reviews

Run both reviewers on the changed files. Fix Critical and Major findings only — ignore style and Minor nits.

**4a. Claude Code reviewer**

Invoke `generic-work-item-code-reviewer` with `scope: full` on all implementation files.

For each Critical or Major finding: fix the code, re-run affected tests, re-install if the fix touches runtime behavior.

**4b. CodeRabbit local review**

```bash
coderabbit review --plain
```

If `coderabbit` CLI is not installed: skip and note it in the PR body.

For each significant finding (logic errors, correctness, contract violations): fix code, re-run tests, re-run review until clean or only style findings remain. Style, formatting, naming: skip entirely.

---

### 5. Commit

Stage only the specific files from the Implementation Reports plus any files touched by Steps 1–4:
```bash
git add {file1} {file2} ...
```

Never `git add -A` or `git add .`.

```bash
git commit -m "[{TICKET}] {one-line summary}"
```

---

### 6. Push

```bash
git push -u origin {BRANCH_NAME}
```

---

### 7. Create draft PR

```bash
gh pr create --draft \
  --title "[{TICKET}] {brief description}" \
  --label "ai-managed-pr" \
  --body "$(cat <<'EOF'
## Addresses

{TICKET}

## Summary

{bullet points derived from the Implementation Reports — one per area}

## Test plan

{checklist from acceptance criteria — mark items verified manually with ✅}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Store the PR number. In autonomous mode: if diff >1000 lines, note it in the PR body and proceed. In pause mode: warn and ask.

---

### 8. CI and bot tracking loop

Iterate until **all** of the following are true:
- All CI checks are passing
- No blocking CodeRabbit issues
- No unresolved Dangerbot issues

**Never trigger `@coderabbitai review` manually** — let CodeRabbit and Dangerbot run on the PR naturally. Only poll for their output.

**Each iteration:**

**8a. Check CI:**
```bash
gh pr checks {PR_NUMBER}
```

For each failing check: read the failure log (`gh run view {run_id} --log-failed`), fix the root cause, commit (`[{TICKET}] fix: {description}`), push.

**8b. Check CodeRabbit:**
```bash
gh api repos/{REPO_NAME}/pulls/{PR_NUMBER}/reviews
gh api repos/{REPO_NAME}/pulls/{PR_NUMBER}/comments
```

Evaluate each finding before acting:
- Fix: genuine correctness issues, contract violations, missing error handling
- Skip: style preferences, naming opinions, subjective suggestions

**8c. Check Dangerbot:**
```bash
gh api repos/{REPO_NAME}/issues/{PR_NUMBER}/comments
```

| Issue | Fix |
|---|---|
| Missing `## Addresses` | `gh pr edit {PR_NUMBER} --body "{corrected body}"` |
| PR too large | Note in body; ask user in pause mode, proceed in autonomous |
| Missing labels | `gh pr edit {PR_NUMBER} --add-label "{label}"` |

After any code change: push → return to 8a.

**Loop exit:** all CI green + no blocking issues → proceed to Step 9.

---

### 9. Slack notification

Invoke `generic-work-item-slack-notify` with:
- `ticket` — the Jira ticket key
- `summary` — the ticket title
- `pr_url` — the PR URL from Step 7
- `work_tree` — worktree path from `git rev-parse --show-toplevel` (resolved in Step 0)
- `status` — `CI: green | CodeRabbit: reviewed | Dangerbot: resolved`

The skill resolves the current Slack user automatically and sends to their personal channel. If it fails for any reason, log and continue — never block on this step.

---

### 10. Done

> "Draft PR ready for human review: {PR_URL}"

## Constraints

- Never `git add -A` or `git add .` — always stage specific files
- Never squash-merge — draft PR creation is the final action; merging is a human decision
- **Never trigger `@coderabbitai review` on GitHub** — let bots run naturally; only read their output
- Do not proceed past Step 2 if tests are failing
- Do not proceed past Step 3 if the app crashes on open
- Evaluate CodeRabbit and Dangerbot findings before fixing — skip style, naming, subjective suggestions
- CI failures must be fixed before the loop exits
- Slack notification is best-effort — never block on it
- In autonomous mode: never stop between steps — execute the full sequence in one continuous turn
- If `gh` CLI unavailable: stop immediately
- If `coderabbit` CLI unavailable: skip Step 4b, note in PR body
