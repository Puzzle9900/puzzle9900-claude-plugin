---
name: generic-pr-merge
description: Create a branch from current changes, push, open a PR, wait for CI checks to pass, squash-merge to main, and pull latest main locally
type: generic
---

# generic-pr-merge

## Context
This skill automates the full GitHub PR lifecycle: branch creation, commit, push, PR creation, CI monitoring, merge, and local sync. Use it whenever you have local changes ready to ship to main through a PR.

## Instructions

You are a release engineer. Take the user's local changes (staged, unstaged, or on a feature branch) through the complete PR-to-main pipeline in one shot.

## Steps

1. **Assess current state**
   - Run `git status` and `git diff --stat` to identify what will be committed.
   - Run `git log --oneline -5` to understand recent commit style.
   - If there are no changes to commit, stop and inform the user.

2. **Create a feature branch**
   - Derive a short, descriptive kebab-case branch name from the changes (e.g., `fix-restore-script-auto-select`).
   - Run `git checkout -b <branch-name>` from the current branch (usually `main`).

3. **Commit changes**
   - Stage only the relevant files by name (avoid `git add .` or `git add -A`).
   - Write a concise commit message following the repo's existing style (check recent `git log`).
   - Always include the `Co-Authored-By: Claude` trailer.
   - Use a HEREDOC to pass the commit message for proper formatting.

4. **Push the branch**
   - Run `git push -u origin <branch-name>`.

5. **Create the Pull Request**
   - Use `gh pr create` with explicit `--base main --head <branch-name>`.
   - Title: short, under 70 characters, matches commit message style.
   - Body format:
     ```
     ## Summary
     - <1-3 bullet points describing the change>

     ## Test plan
     - [ ] <verification steps>

     Generated with [Claude Code](https://claude.com/claude-code)
     ```
   - Use a HEREDOC for the body.

6. **Handle "not up to date" errors**
   - If the PR cannot be created or merged because the branch is behind main:
     - `git fetch origin main`
     - `git rebase origin/main`
     - `git push --force-with-lease`
   - Retry the failed operation after rebasing.

7. **Wait for CI checks**
   - Run `gh pr checks <pr-number> --watch` with a generous timeout (up to 5 minutes).
   - If any check fails, investigate the failure and report to the user before proceeding.

8. **Merge the PR**
   - Use `gh pr merge <pr-number> --squash` (this repo requires squash merges).
   - If squash merge fails due to branch protection, try `--admin` flag.
   - If `--admin` also fails, report the blocker to the user.

9. **Sync local main**
   - `git checkout main`
   - `git pull origin main`
   - Confirm the merge commit is present in local history.

10. **Report completion**
    - Share the PR URL and confirm it was merged.

## Constraints
- Never use `git add .` or `git add -A` -- always stage specific files by name
- Never skip CI checks -- always wait for them to pass before merging
- Never use `--no-verify` or `--no-gpg-sign`
- Always use squash merge (this repo disallows merge commits)
- Always rebase instead of merge when syncing with main
- If CI checks fail, do NOT auto-merge -- report the failure and stop
- Do not delete the remote branch manually; GitHub handles cleanup on merge
- Always confirm with the user before proceeding if the diff contains files that look sensitive (.env, credentials, secrets)
