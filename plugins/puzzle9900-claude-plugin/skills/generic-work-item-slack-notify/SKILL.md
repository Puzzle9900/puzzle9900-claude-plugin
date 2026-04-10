---
name: generic-work-item-slack-notify
description: Sends a Slack DM to the currently authenticated Slack user notifying them that a work item PR is ready for review. Called by generic-work-item-ship at the end of the ship phase.
---

# generic-work-item-slack-notify

## Overview

Resolves the current Slack user's identity and sends them a direct message summarising the completed work item. Always sends to the current user's own personal channel — no configuration needed.

## Inputs

| Input | Required | Description |
|---|---|---|
| `ticket` | Yes | Jira ticket key (e.g. `MOB-1234`) |
| `summary` | Yes | Ticket title / one-line description |
| `pr_url` | Yes | Full GitHub PR URL |
| `work_tree` | No | Worktree path where the implementation was done (from `git rev-parse --show-toplevel`). Omit if unknown. |
| `status` | No | Short status line (e.g. `CI: green \| CodeRabbit: reviewed`). Defaults to `PR ready for review`. |

## Steps

### 1. Resolve current Slack user

The `slack_get_users_identity` tool does not exist in the Slack MCP. Instead, use `ToolSearch` to load the schema for `mcp__claude_ai_Slack__slack_send_message`. The tool description embeds the authenticated user's Slack member ID in this sentence:

> "If the user wants to send a message to themselves, the current logged in user's user_id is UXXXXXXXXX."

Extract the ID from that description (e.g. `U0A4CF0712L`). This is used as the `channel_id` — sending to your own member ID creates a DM to yourself.

```
ToolSearch: select:mcp__claude_ai_Slack__slack_send_message
→ read "current logged in user's user_id is ..." from the description
```

If the schema cannot be loaded or the ID is not found, log the error and stop. Do not hardcode a member ID.

### 2. Send the message

Build the message body. Include the `work_tree` line only if the input was provided:

```
slack_send_message:
  channel: {member_id}
  text: |
    ✅ *[{ticket}] {summary}*
    Worktree: `{work_tree}`     ← omit this line if work_tree is not provided
    {pr_url}
    {status}
```

### 3. Confirm

Log: `Slack notification sent to {member_id}.`

## Constraints

- Always resolve the user identity dynamically — never hardcode a channel or member ID
- Only sends to the current user's personal channel — not a team channel
- If Slack MCP is unavailable or identity resolution fails, log the error and return — never block the ship workflow
