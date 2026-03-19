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
      # Register mapping and update path variables
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
