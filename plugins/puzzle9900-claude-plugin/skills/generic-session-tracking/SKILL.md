---
name: generic-session-tracking
description: Set up or verify session tracking for a Claude Code project — logs every prompt and response to .claude/sessions/<session-id>/session.log. Installs hooks, creates folder structure, and records consent on first run; verifies and repairs artifacts on re-runs. Suggest this when a user wants to keep a history of their Claude conversations or when setting up a new project with Claude Code.
type: generic
---

# generic-session-tracking

## Context

This skill installs automatic session logging in any Claude Code project. Once enabled:

- Every Claude session gets a dedicated folder under `.claude/sessions/<session-id>/`
- A `session.log` records every user prompt and the associated response
- Logs are stored locally, gitignored, and never leave the machine

The **first run** asks for consent and installs everything. **Subsequent runs** skip the consent prompt and instead verify that all required artifacts are present, repairing any that are missing.

Use this skill when:
- A user wants a history of prompts and responses for a project
- Setting up Claude Code in a new project and wanting observability
- The user asks whether past sessions were logged or can be logged

## Instructions

You are a Claude Code setup assistant. Your job is to:

1. Detect whether session tracking is already configured (enabled or disabled).
2. If not yet configured, ask the user once for consent.
3. If consented, install all required files and settings idempotently — skip any artifact that already exists and is correct; repair any that are missing or incorrect.
4. Never overwrite or remove settings or hook entries that belong to other features.

## Steps

### 1. Check for an existing consent decision

Check the following locations **in order** and stop at the first match:

1. `.claude/sessions/.tracking-enabled` — presence means opted in
2. `.claude/sessions/.tracking-disabled` — presence means opted out

**If tracking is already enabled** (marker found): report "Session tracking is already enabled" and proceed to **Step 4** to verify and repair all artifacts — hook script, settings entries, and directory files. Do **not** ask for consent again.

**If tracking is disabled** (marker found): report "Session tracking was previously disabled." Tell the user: to opt in again, delete `.claude/sessions/.tracking-disabled` and re-run `/generic-session-tracking`. Stop here.

**If no marker is found**: proceed to Step 2.

### 2. Ask for consent (first-time only)

Present this prompt to the user:

> **Session Tracking Setup**
>
> This will log every prompt and Claude's response for each session to:
> ```
> .claude/sessions/<session-id>/session.log
> ```
> Logs are stored **locally only** and gitignored — they never leave this machine.
> Each session gets its own folder identified by session ID.
>
> Note: prompts may contain sensitive information. Since logs are local only, they are not shared — but be aware of this if others have access to your machine.
>
> Would you like to enable session tracking for this project? **(yes / no)**

Wait for the user's response before proceeding.

### 3. If user says NO

- Create `.claude/sessions/` if it doesn't exist
- Create `.claude/sessions/.gitignore` if it doesn't exist with the following content (so the directory is always gitignored regardless of consent decision):
  ```
  # Session logs are local only — do not commit
  *
  !.gitignore
  !.tracking-enabled
  !.tracking-disabled
  ```
- Create an empty file `.claude/sessions/.tracking-disabled`
- Stop. Tell the user they can re-run `/generic-session-tracking` at any time to opt in.

### 4. Create or verify the hook script and dependencies

This step runs on first install (user said YES in Step 2) and on re-runs (when tracking was already enabled and Step 1 redirected here). All actions are idempotent.

Verify that `jq` is available:
```bash
which jq
```
If not found, warn the user:
> `jq` is required for session tracking hooks. Install it with `brew install jq` (macOS) or `apt install jq` (Linux), then re-run this skill.

Stop if `jq` is missing.

Create `.claude/hooks/` if it doesn't exist. Write the following script to `.claude/hooks/session-tracker.sh` (overwrite if it already exists to ensure the canonical version is installed):

```bash
#!/usr/bin/env bash
# session-tracker.sh — logs prompts and responses to .claude/sessions/<name>/session.log
# Invoked by Claude Code hooks: UserPromptSubmit and Stop
set -euo pipefail

PAYLOAD="$(cat)"
HOOK_EVENT="$(echo "$PAYLOAD" | jq -r '.hook_event_name // empty')"
SESSION_ID="$(echo "$PAYLOAD" | jq -r '.session_id // empty')"
TRANSCRIPT_PATH="$(echo "$PAYLOAD" | jq -r '.transcript_path // empty')"

[[ -z "$SESSION_ID" || -z "$HOOK_EVENT" ]] && exit 0

SESSIONS_DIR=".claude/sessions"
INDEX_FILE="$SESSIONS_DIR/.session-index"

mkdir -p "$SESSIONS_DIR"

# Returns the mapped folder name for a session_id, or empty if not yet indexed
lookup_name() {
  [[ -f "$INDEX_FILE" ]] || { echo ""; return; }
  awk -F'\t' -v id="$1" '$1==id{print $2; exit}' "$INDEX_FILE" 2>/dev/null || echo ""
}

# Returns 0 if a folder name is already in use (directory or index entry), 1 otherwise
name_taken() {
  local name="$1"
  [[ -d "$SESSIONS_DIR/$name" ]] && return 0
  if [[ -f "$INDEX_FILE" ]]; then
    awk -F'\t' -v n="$name" 'BEGIN{f=0} $2==n{f=1} END{exit 1-f}' "$INDEX_FILE" 2>/dev/null && return 0
  fi
  return 1
}

# Generate a kebab-case slug from text (max 40 chars)
make_slug() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs 'a-z0-9' '-' \
    | sed 's/^-*//; s/-*$//' \
    | cut -c1-40 \
    | sed 's/-*$//'
}

# Resolve current session folder — use indexed name if available, fall back to session ID
FOLDER_NAME="$(lookup_name "$SESSION_ID")"
[[ -z "$FOLDER_NAME" ]] && FOLDER_NAME="$SESSION_ID"
SESSION_DIR="$SESSIONS_DIR/$FOLDER_NAME"
LOG_FILE="$SESSION_DIR/session.log"
LOGGED_COUNT_FILE="$SESSION_DIR/.logged_response_count"

mkdir -p "$SESSION_DIR"

# Write session header on first use
if [[ ! -f "$LOG_FILE" ]]; then
  printf '# Session: %s\n' "$SESSION_ID" > "$LOG_FILE"
fi

flush_responses() {
  [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]] || return 0

  local logged_count total_count
  logged_count=$(cat "$LOGGED_COUNT_FILE" 2>/dev/null || echo "0")
  total_count=$(jq -sr '[.[] | select(.type=="assistant")] | length' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")

  (( total_count > logged_count )) || return 0

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  for (( i=logged_count; i<total_count; i++ )); do
    local response
    response=$(jq -sr --argjson idx "$i" \
      '[[.[] | select(.type=="assistant")][$idx].message.content[]? | select(.type=="text") | .text] | join("\n")' \
      "$TRANSCRIPT_PATH" 2>/dev/null | head -c 16384 || true)
    [[ -n "$response" ]] && printf '\n### Response [%s]\n\n%s\n' "$ts" "$response" >> "$LOG_FILE"
  done
  echo "$total_count" > "$LOGGED_COUNT_FILE"
}

if [[ "$HOOK_EVENT" == "UserPromptSubmit" ]]; then
  PROMPT="$(echo "$PAYLOAD" | jq -r '.prompt // empty')"
  [[ -z "$PROMPT" ]] && exit 0

  # On the first prompt, rename the session folder to a human-readable slug
  if [[ -z "$(lookup_name "$SESSION_ID")" ]]; then
    slug="$(make_slug "$PROMPT")"
    if [[ -n "$slug" ]]; then
      # Find a unique name (append -2, -3, ... on collision)
      candidate="$slug"
      n=2
      while name_taken "$candidate"; do
        candidate="${slug}-${n}"
        n=$(( n + 1 ))
      done
      # Rename the folder (previously named by session ID)
      [[ "$SESSION_DIR" != "$SESSIONS_DIR/$candidate" ]] && mv "$SESSION_DIR" "$SESSIONS_DIR/$candidate"
      printf '%s\t%s\n' "$SESSION_ID" "$candidate" >> "$INDEX_FILE"
      SESSION_DIR="$SESSIONS_DIR/$candidate"
    else
      # Prompt had no usable characters; keep session ID as folder name
      printf '%s\t%s\n' "$SESSION_ID" "$SESSION_ID" >> "$INDEX_FILE"
    fi
    LOG_FILE="$SESSION_DIR/session.log"
    LOGGED_COUNT_FILE="$SESSION_DIR/.logged_response_count"
  fi

  # Flush any response Stop may have missed (safety net)
  flush_responses
  printf '\n---\n\n## Prompt [%s]\n\n%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$PROMPT" >> "$LOG_FILE"

elif [[ "$HOOK_EVENT" == "Stop" ]]; then
  # Retry for up to ~3 seconds — transcript may not be written when Stop fires
  logged_before=$(cat "$LOGGED_COUNT_FILE" 2>/dev/null || echo "0")
  for attempt in 1 2 3 4 5 6; do
    flush_responses
    logged_after=$(cat "$LOGGED_COUNT_FILE" 2>/dev/null || echo "0")
    (( logged_after > logged_before )) && break
    sleep 0.5
  done
fi

exit 0
```

Make the script executable:
```bash
chmod +x .claude/hooks/session-tracker.sh
```

### 5. Register the hooks in settings

Read `.claude/settings.local.json` (create it as `{}` if it doesn't exist). The goal is to **merge** the hook entries into the file — never replace it wholesale. Preserve every existing key, including `permissions`, other `hooks` entries, and any other top-level fields.

Add or update only these keys:

- Under `hooks.UserPromptSubmit`: append the session-tracker entry (shown below) **only if no existing entry already contains `session-tracker.sh`**.
- Under `hooks.Stop`: same — append only if not already present.

The session-tracker hook entry to add under each event:
```json
{
  "hooks": [
    {
      "type": "command",
      "command": "bash .claude/hooks/session-tracker.sh"
    }
  ]
}
```

Full merge rules:
- If `hooks.UserPromptSubmit` does not exist, create it as an array containing the entry above.
- If `hooks.UserPromptSubmit` already exists as an array, inspect each element. If any element's `hooks[].command` contains `session-tracker.sh`, skip the append. Otherwise, append the entry.
- Apply the same logic to `hooks.Stop`.
- If the top-level `hooks` key does not exist, create it.
- Never remove or overwrite other existing hook entries or top-level settings keys.

### 6. Create the sessions directory and gitignore

All actions in this step are idempotent — skip any item that already exists and is correct.

- Create `.claude/sessions/` if it doesn't exist.
- Create `.claude/sessions/.gitignore` if it doesn't exist (do not overwrite an existing one). Content:
  ```
  # Session logs are local only — do not commit
  *
  !.gitignore
  !.tracking-enabled
  !.tracking-disabled
  ```
- Create an empty `.claude/sessions/.tracking-enabled` file if it doesn't already exist.

### 7. Update .gitignore at the project root (if it exists)

If a `.gitignore` exists in the project root, check whether `.claude/sessions/` is already excluded. If not, append:
```
# Claude session logs
.claude/sessions/
```

If no root `.gitignore` exists, skip this step.

### 8. Confirm to the user

If this was a **first-time install**, report:
- Session tracking is now **enabled**
- Hook script: `.claude/hooks/session-tracker.sh`
- Sessions stored in: `.claude/sessions/<session-id>/session.log`
- Logs are gitignored and never committed
- Takes effect starting with the **next** user prompt (prompts sent before this setup in the current session are not retroactively captured)
- To **disable** tracking later: delete `.claude/sessions/.tracking-enabled`, create `.claude/sessions/.tracking-disabled`, and remove the `session-tracker.sh` entries from `hooks.UserPromptSubmit` and `hooks.Stop` in `.claude/settings.local.json`.

If this was a **re-run** (already enabled): report:
- Session tracking was already enabled — all artifacts verified
- List any artifacts that were missing and were repaired during this run
- If everything was already in place: "All session tracking artifacts are present and correct."

## Constraints

- Never commit session logs to git — `.claude/sessions/` must always be gitignored
- Always check for `jq` availability before installing; stop and warn if missing
- All installation steps must be **idempotent**: skip artifacts that already exist and are correct; repair or create those that are missing
- Always **merge** settings — never overwrite or remove existing hooks, permissions, or other settings keys
- Use `.claude/settings.local.json` by default (personal, not committed); only use `.claude/settings.json` if the user explicitly requests a team-shared setup
- `.tracking-enabled` / `.tracking-disabled` files are the authoritative consent markers — they must be written on opt-in/opt-out. Do NOT write a `sessionTracking` key to `settings.local.json` (Claude Code rejects unknown fields)
- The hook script must exit `0` on all non-fatal conditions (missing data, missing transcript, etc.) to avoid blocking Claude's normal operation
- Session logs may contain sensitive information — remind the user at setup time that they are local only
- This skill is fully generic — no references to specific projects, repos, app names, or organization conventions
- If session tracking is already configured, do not ask for consent again — check the marker, report current status, and proceed to verify/repair artifacts
