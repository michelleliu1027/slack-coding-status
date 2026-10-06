#!/bin/bash
# coding-detect.sh - Detect if user is actively coding and update Slack status
# Runs via LaunchAgent every CODING_POLL_INTERVAL seconds (see install.sh)
# Usage: coding-detect.sh [--debug]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

AWAY_IDLE="${CODING_AWAY_IDLE:-300}"       # keyboard/mouse idle seconds that count as "not at desk"
GRACE="${CODING_GRACE:-60}"                # seconds to keep status after switching to a non-coding app
REFRESH="${CODING_REFRESH:-600}"           # re-push status this often so Slack's expiry can't drop it

STATE_FILE="/tmp/.coding-status-active"    # exists => status is set in Slack; contents = last push epoch
LAST_ACTIVE_FILE="/tmp/.coding-last-active"

CODING_APPS="${CODING_APPS:-Code,Code - Insiders,Cursor,Windsurf,Zed,Terminal,iTerm2,Warp,Alacritty,kitty,Ghostty,WezTerm,ChatGPT,Claude}"
CODING_BUNDLE_IDS="${CODING_BUNDLE_IDS:-com.openai.codex,com.anthropic.claudefordesktop,com.microsoft.VSCode,com.microsoft.VSCodeInsiders,com.todesktop.230313mzl4w4u92,com.exafunction.windsurf,dev.zed.Zed,com.apple.Terminal,com.googlecode.iterm2,dev.warp.Warp-Stable,io.alacritty,net.kovidgoyal.kitty,com.mitchellh.ghostty,com.github.wez.wezterm}"

DEBUG=""
[ "$1" = "--debug" ] && DEBUG=1
log() { [ -n "$DEBUG" ] && echo "$*"; }

hid_idle_seconds() {
  ioreg -c IOHIDSystem 2>/dev/null \
    | awk '/HIDIdleTime/ { print int($NF / 1000000000); exit }'
}

screen_is_locked() {
  ioreg -n Root -d1 -r -k IOConsoleUsers 2>/dev/null \
    | grep -q 'kCGSSessionScreenIsLocked=Yes'
}

# Frontmost app via lsappinfo. AppleScript/System Events needs an Automation
# permission that, when missing, fails silently and reports no front app at all.
front_app_name=""
front_app_bundle=""
read_front_app() {
  local asn info
  asn=$(lsappinfo front 2>/dev/null)
  [ -n "$asn" ] || return 1
  info=$(lsappinfo info -only name -only bundleid "$asn" 2>/dev/null)
  front_app_name=$(printf '%s\n' "$info" | sed -n 's/.*"LSDisplayName"="\([^"]*\)".*/\1/p')
  front_app_bundle=$(printf '%s\n' "$info" | sed -n 's/.*"CFBundleIdentifier"="\([^"]*\)".*/\1/p')
  [ -n "$front_app_name" ] || [ -n "$front_app_bundle" ]
}

in_csv_list() {
  local needle="$1" list="$2" item items
  [ -n "$needle" ] || return 1
  IFS=',' read -ra items <<< "$list"
  for item in "${items[@]}"; do
    [ "$needle" = "$item" ] && return 0
  done
  return 1
}

set_status() {
  if [ -n "$DEBUG" ]; then
    log "would run:  slack-status.sh $1"
    return
  fi
  "$SCRIPT_DIR/slack-status.sh" "$1"
}

NOW=$(date +%s)
IDLE=$(hid_idle_seconds)
read_front_app

if screen_is_locked; then
  PRESENT=0
  PRESENCE_REASON="screen locked"
elif [ -z "$IDLE" ]; then
  # Don't let an unreadable idle clock pin the status on forever.
  PRESENT=0
  PRESENCE_REASON="HIDIdleTime unreadable"
elif [ "$IDLE" -ge "$AWAY_IDLE" ]; then
  PRESENT=0
  PRESENCE_REASON="input idle ${IDLE}s >= ${AWAY_IDLE}s"
else
  PRESENT=1
  PRESENCE_REASON="input idle ${IDLE}s"
fi

if in_csv_list "$front_app_bundle" "$CODING_BUNDLE_IDS" || in_csv_list "$front_app_name" "$CODING_APPS"; then
  CODING_APP=1
else
  CODING_APP=0
fi

log "front app:  ${front_app_name:-<unknown>} (${front_app_bundle:-<unknown>})"
log "coding app: $CODING_APP"
log "present:    $PRESENT ($PRESENCE_REASON)"
log "status set: $([ -f "$STATE_FILE" ] && echo yes || echo no)"

if [ "$PRESENT" -eq 1 ] && [ "$CODING_APP" -eq 1 ]; then
  echo "$NOW" > "$LAST_ACTIVE_FILE"

  if [ ! -f "$STATE_FILE" ]; then
    log "decision:   set active"
    set_status active
  else
    LAST_PUSH=$(cat "$STATE_FILE" 2>/dev/null)
    if [ -z "$LAST_PUSH" ] || [ "$(( NOW - LAST_PUSH ))" -ge "$REFRESH" ]; then
      log "decision:   refresh active"
      set_status active
    else
      log "decision:   already active, no-op"
    fi
  fi
  exit 0
fi

if [ ! -f "$STATE_FILE" ]; then
  log "decision:   not coding, status already clear, no-op"
  exit 0
fi

# Walking away or locking the screen clears immediately. The grace period only
# covers app switches (checking Slack, reading docs); it must never let a
# long-lived editor window hold the status open while nobody is at the desk.
if [ "$PRESENT" -eq 0 ]; then
  log "decision:   clear now ($PRESENCE_REASON)"
  set_status idle
  exit 0
fi

LAST_ACTIVE=$(cat "$LAST_ACTIVE_FILE" 2>/dev/null)
if [ -z "$LAST_ACTIVE" ]; then
  log "decision:   clear now (no last-active record)"
  set_status idle
  exit 0
fi

ELAPSED=$(( NOW - LAST_ACTIVE ))
if [ "$ELAPSED" -ge "$GRACE" ]; then
  log "decision:   clear (left coding app ${ELAPSED}s ago >= ${GRACE}s)"
  set_status idle
else
  log "decision:   hold ($((GRACE - ELAPSED))s of grace left)"
fi
