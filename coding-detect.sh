#!/bin/bash
# coding-detect.sh - Detect if user is actively coding and update Slack status
# Runs via LaunchAgent every few minutes

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IDLE_THRESHOLD="${CODING_IDLE_THRESHOLD:-900}"  # seconds (default 15 min)
STATE_FILE="/tmp/.coding-status-active"
LAST_ACTIVE_FILE="/tmp/.coding-last-active"

# Get the frontmost application (macOS)
FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)

# Check if Claude Code is running in any terminal
CLAUDE_RUNNING=$(pgrep -f "claude" 2>/dev/null)

# Coding apps to detect (customize via CODING_APPS env var)
CODING_APPS="${CODING_APPS:-Code,Code - Insiders,Cursor,Terminal,iTerm2,Warp,Alacritty,kitty,Windsurf}"

is_coding_app() {
  IFS=',' read -ra APPS <<< "$CODING_APPS"
  for app in "${APPS[@]}"; do
    if [ "$1" = "$app" ]; then
      return 0
    fi
  done
  return 1
}

NOW=$(date +%s)

if is_coding_app "$FRONT_APP" || [ -n "$CLAUDE_RUNNING" ]; then
  echo "$NOW" > "$LAST_ACTIVE_FILE"

  if [ ! -f "$STATE_FILE" ]; then
    "$SCRIPT_DIR/slack-status.sh" active
  fi
else
  if [ -f "$LAST_ACTIVE_FILE" ]; then
    LAST_ACTIVE=$(cat "$LAST_ACTIVE_FILE")
    ELAPSED=$(( NOW - LAST_ACTIVE ))

    if [ "$ELAPSED" -ge "$IDLE_THRESHOLD" ] && [ -f "$STATE_FILE" ]; then
      "$SCRIPT_DIR/slack-status.sh" idle
    fi
  fi
fi
