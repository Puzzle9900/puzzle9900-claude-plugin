#!/usr/bin/env bash
# open-claude-tab.sh — Open a new iTerm2 tab with a Claude session in a worktree.
# Uses a temp .command file + open — no AppleScript, no Python.
#
# Usage:
#   open-claude-tab.sh [OPTIONS]
#
# Options:
#   -t <title>    Tab/window title and Claude --name session label
#   -r <repo>     Absolute path to the git repo root
#   -w <name>     Worktree name (e.g. story/MOB-1234/add-dark-mode)
#                 If worktree exists, re-enters it. If not, creates it via claude --worktree.
#   -m <message>  Initial message passed to claude as a positional argument (NOT -p)
#   -k            Caffeinate — prevent Mac from sleeping while Claude runs
#   -p            Pass --dangerously-skip-permissions to Claude
#   -h            Show this help
#
# Examples:
#   open-claude-tab.sh -t "story/MOB-1234/add-dark-mode" \
#                      -r "/Users/you/projects/my-app" \
#                      -w "story/MOB-1234/add-dark-mode" \
#                      -m "/generic-work-item-full-implementation-workflow MOB-1234" \
#                      -p

set -euo pipefail

TITLE="claude"
REPO=""
WORKTREE_NAME=""
MESSAGE=""
CAFFEINATE=false
SKIP_PERMISSIONS=false

usage() {
  sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
  exit 0
}

while getopts ":t:r:w:m:kph" opt; do
  case $opt in
    t) TITLE="$OPTARG" ;;
    r) REPO="$OPTARG" ;;
    w) WORKTREE_NAME="$OPTARG" ;;
    m) MESSAGE="$OPTARG" ;;
    k) CAFFEINATE=true ;;
    p) SKIP_PERMISSIONS=true ;;
    h) usage ;;
    :) echo "Error: -$OPTARG requires an argument" >&2; exit 1 ;;
    \?) echo "Error: unknown option -$OPTARG" >&2; exit 1 ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────

missing=()
[[ -z "$TITLE" ]]         && missing+=("-t")
[[ -z "$REPO" ]]          && missing+=("-r")
[[ -z "$WORKTREE_NAME" ]] && missing+=("-w")
[[ -z "$MESSAGE" ]]       && missing+=("-m")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Error: missing required argument(s): ${missing[*]}" >&2
  echo "Usage: $(basename "$0") -t <title> -r <repo> -w <worktree-name> -m <message> [-k] [-p]" >&2
  exit 1
fi

if [[ "$REPO" != /* ]]; then
  echo "Error: -r must be an absolute path (got: $REPO)" >&2
  exit 1
fi

if [[ ! -d "$REPO" ]]; then
  echo "Error: repo directory does not exist: $REPO" >&2
  exit 1
fi

# ── Resolve paths and flags before writing the .command file ─────────────────

WORKTREE_DIR_NAME="$(echo "$WORKTREE_NAME" | tr '/' '+')"
EXISTING_WORKTREE="${REPO}/.claude/worktrees/${WORKTREE_DIR_NAME}"

PERMISSIONS_FLAG=""
$SKIP_PERMISSIONS && PERMISSIONS_FLAG="--dangerously-skip-permissions"

CAFFEINATE_FLAG=""
$CAFFEINATE && CAFFEINATE_FLAG="--caffeinate"

# ── Prune stale git worktree references ──────────────────────────────────────
# Ensures claude --worktree can create cleanly even if a previous directory was deleted.

git -C "${REPO}" worktree prune 2>/dev/null || true

# ── Write .command file ───────────────────────────────────────────────────────

rm -f /tmp/open-claude-tab-*.command 2>/dev/null || true
TMPFILE="$(mktemp /tmp/open-claude-tab-XXXX.command)"
chmod +x "$TMPFILE"

if [[ -d "$EXISTING_WORKTREE" ]]; then
  cat > "$TMPFILE" << BOOTSTRAP
#!/bin/zsh -l
LOG="/tmp/claude-worktree-launch-\$(date +%Y%m%d-%H%M%S).log"
cd "${EXISTING_WORKTREE}"
{
  echo "Log: \$LOG"
  echo "Re-entering existing worktree: ${EXISTING_WORKTREE}"
  echo "Working directory: \$(pwd)"
  echo "Running: claude \"${MESSAGE}\" --name \"${TITLE}\" ${PERMISSIONS_FLAG} ${CAFFEINATE_FLAG}"
} 2>&1 | tee "\$LOG"
exec claude "${MESSAGE}" --name "${TITLE}" ${PERMISSIONS_FLAG} ${CAFFEINATE_FLAG}
BOOTSTRAP
else
  cat > "$TMPFILE" << BOOTSTRAP
#!/bin/zsh -l
LOG="/tmp/claude-worktree-launch-\$(date +%Y%m%d-%H%M%S).log"
cd "${REPO}"
{
  echo "Log: \$LOG"
  echo "Creating new worktree"
  echo "Working directory: \$(pwd)"
  echo "Running: claude \"${MESSAGE}\" --name \"${TITLE}\" --worktree \"${WORKTREE_NAME}\" ${PERMISSIONS_FLAG} ${CAFFEINATE_FLAG}"
} 2>&1 | tee "\$LOG"
exec claude "${MESSAGE}" --name "${TITLE}" --worktree "${WORKTREE_NAME}" ${PERMISSIONS_FLAG} ${CAFFEINATE_FLAG}
BOOTSTRAP
fi

open -a iTerm "$TMPFILE"
