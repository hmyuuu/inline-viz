#!/usr/bin/env bash
# hook-display.sh — PostToolUse hook that displays images inline
# Triggered after Bash tool calls. Scans output for vizrender/vizshow tags
# and displays the referenced image directly to the terminal.
#
# Hook output goes to the terminal (not captured by Claude Code),
# so escape sequences from vizshow will actually render.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIZSHOW="$SCRIPT_DIR/vizshow"

# Read hook JSON from stdin
INPUT=$(cat)

# Extract tool_response.stdout (where vizrender prints its tags)
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // empty' 2>/dev/null)

if [[ -z "$STDOUT" ]]; then
  exit 0
fi

# Look for [vizrender: displayed=/path/to/file.png]
DISPLAYED=$(echo "$STDOUT" | sed -n 's/.*\[vizrender: displayed=\([^]]*\)\].*/\1/p' | tail -1)

# Also look for standalone [vizshow: /path/to/file via protocol]
if [[ -z "$DISPLAYED" ]]; then
  DISPLAYED=$(echo "$STDOUT" | sed -n 's/.*\[vizshow: \([^ ]*\) via .*/\1/p' | tail -1)
fi

if [[ -z "$DISPLAYED" || ! -f "$DISPLAYED" ]]; then
  exit 0
fi

# Display the image directly to the terminal
# This bypasses Claude Code's output capture — escape sequences render
"$VIZSHOW" "$DISPLAYED" --quiet >&2

exit 0
