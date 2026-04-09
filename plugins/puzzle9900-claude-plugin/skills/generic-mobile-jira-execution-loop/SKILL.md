---
name: generic-mobile-jira-execution-loop
description: Polls Jira on a configurable interval and automatically launches the worktree setup skill for every ticket assigned to the current user in the active sprint that is in a ready-to-develop state. Runs as a continuous loop in the current Claude session — no background processes, no extra terminals.
---

# generic-mobile-jira-execution-loop

## Overview

A continuous loop that runs inside the current Claude session. Each iteration polls Jira for ready tickets and invokes `generic-work-item-worktree-setup` for each one. Between iterations, Claude waits using `sleep` via the Bash tool — the session stays open and resumes automatically when the interval elapses.

Jira is the source of truth. Tickets that have been set up will be In Progress and will not appear in subsequent queries.

## Invocation

```
/generic-mobile-jira-execution-loop 10m
```

Polling interval as the first argument. Accepts seconds, minutes, or hours (`30s`, `5m`, `10m`, `1h`). Defaults to `10m` if not provided.

## Loop Pseudocode

```
interval_seconds = parse_to_seconds(args[0] ?? "10m")

loop forever:

  log("[{now}] Polling Jira...")

  user    = run skill /generic-jira-contributor-context
  sprint  = user.active_sprint          // exact sprint ID — never openSprints()
  tickets = jira.search(
    assignee = user.account_id,
    sprint   = sprint.id,
    status   IN ["Draft", "Ready", "Ready for Development", "To Do", "Backlog"]
  )

  if tickets is empty:
    log("[{now}] No new tickets.")
  else:
    ask user (AskUserQuestion):
      question: "Found {N} ticket(s) ready to develop: {KEY1}, {KEY2}... Which would you like to start?"
      options:
        - "All tickets"
        - "{KEY1} — {summary1}"
        - "{KEY2} — {summary2}"
        - ... (one option per ticket)

    selected = user selection

    for each ticket in selected (serially):
      log("[{now}] {ticket.key} — invoking setup skill")
      run skill /generic-work-item-worktree-setup with ticket.key

  log("[{now}] Waiting {interval}...")
  bash: sleep {interval_seconds}        // session stays open during wait

  // after sleep returns, continue to next iteration
```

## Steps

### 1. Parse interval

Read the first argument. Parse to seconds:
- `30s` → 30
- `5m` → 300
- `1h` → 3600

Default to `600` (10 minutes) if not provided.

### 2. Loop — repeat forever until the user stops the session

Each iteration:

**2a. Fetch current user context**

Run the `/generic-jira-contributor-context` skill to resolve the authenticated user's account ID and active sprint ID.

**2b. Query Jira**

```
searchJiraIssuesUsingJql:
  jql: assignee = currentUser() AND sprint = {sprint_id} AND status in ("Draft", "Ready", "Ready for Development", "To Do", "Backlog")
  fields: key, summary, issuetype, status
```

**2c. Ask the user which tickets to process**

If no tickets found, log `No new tickets.` and proceed to the wait.

If tickets found, use the AskUserQuestion tool with:
- question: `Found {N} ticket(s) ready to develop. Which would you like to start?`
- options:
  - `All tickets`
  - One option per ticket: `{KEY} — {summary}`
- multiSelect: true

If the user selects "All tickets", process every ticket in the list. Otherwise process only the selected ones.

**2d. For each selected ticket — serially**

Run the `/generic-work-item-worktree-setup` skill with the ticket key.

**2e. Wait**

```bash
sleep {interval_seconds}
```

The Bash tool blocks for the duration. The session stays open. When `sleep` returns, the next iteration begins immediately.

## Constraints

- No local state file — Jira status is the only source of truth
- Never move tickets or create worktrees directly — delegate entirely to `generic-work-item-worktree-setup`
- Always use the exact sprint ID from `generic-jira-contributor-context` — never `openSprints()`
- Process tickets serially — never invoke two setup skills concurrently
- If Atlassian MCP is unavailable on a given iteration, log the error, skip to the wait step, and retry on the next iteration
- Loop runs until the user ends the session (Ctrl+C)
