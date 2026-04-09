#!/usr/bin/env bash
# open-claude-tab.sh — Open a new iTerm2 tab with a Claude session.
# Uses a temp .command file + open — no AppleScript, no Python.
#
# Usage:
#   open-claude-tab.sh [OPTIONS]
#
# Options:
#   -t <title>    Tab/window title
#   -c <args>     Extra args to pass to claude (e.g. "'/generic-work-item-ship'")
#   -d <dir>      Working directory (default: current directory)
#   -k            Caffeinate — prevent Mac from sleeping while Claude runs
#   -p            Pass --dangerously-skip-permissions to Claude
#   -h            Show this help
#
# Examples:
#   open-claude-tab.sh -t "Claude — Feature Branch" -d ~/projects/my-app
#   open-claude-tab.sh -t "Claude — Ship" -c "'/generic-work-item-ship'" -d ~/projects/my-app -k -p

set -euo pipefail

TITLE="claude"
CMD=""
DIR="$(pwd)"
CAFFEINATE=false
SKIP_PERMISSIONS=false

usage() {
  sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
  exit 0
}

while getopts ":t:c:d:kph" opt; do
  case $opt in
    t) TITLE="$OPTARG" ;;
    c) CMD="$OPTARG" ;;
    d) DIR="$OPTARG" ;;
    k) CAFFEINATE=true ;;
    p) SKIP_PERMISSIONS=true ;;
    h) usage ;;
    :) echo "Error: -$OPTARG requires an argument" >&2; exit 1 ;;
    \?) echo "Error: unknown option -$OPTARG" >&2; exit 1 ;;
  esac
done

TMPFILE="$(mktemp /tmp/open-claude-tab-XXXX.command)"
chmod +x "$TMPFILE"

CLAUDE_FLAGS="--name \"${TITLE}\""
$SKIP_PERMISSIONS && CLAUDE_FLAGS="$CLAUDE_FLAGS --dangerously-skip-permissions"
[[ -n "$CMD" ]] && CLAUDE_FLAGS="$CLAUDE_FLAGS $CMD"

if $CAFFEINATE; then
  CLAUDE_INVOCATION="caffeinate -di claude $CLAUDE_FLAGS"
else
  CLAUDE_INVOCATION="claude $CLAUDE_FLAGS"
fi

cat > "$TMPFILE" << BOOTSTRAP
#!/usr/bin/env bash
rm -f "$TMPFILE"
cd "${DIR}"
${CLAUDE_INVOCATION}
BOOTSTRAP

open -a iTerm "$TMPFILE"
