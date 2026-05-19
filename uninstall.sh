#!/bin/bash
# uninstall.sh - Remove slack-coding-status

set -e

echo "=== Uninstalling Slack Coding Status ==="

# Stop and remove LaunchAgent
PLIST_FILE="$HOME/Library/LaunchAgents/com.coding-status.plist"
if [ -f "$PLIST_FILE" ]; then
  launchctl unload "$PLIST_FILE" 2>/dev/null || true
  rm "$PLIST_FILE"
  echo "Removed LaunchAgent"
fi

# Remove scripts
rm -f "$HOME/.local/bin/slack-status.sh"
rm -f "$HOME/.local/bin/coding-detect.sh"
echo "Removed scripts"

# Clean up state files
rm -f /tmp/.coding-status-active
rm -f /tmp/.coding-last-active
echo "Cleaned up state files"

echo ""
echo "Done! You may also want to remove SLACK_STATUS_TOKEN from your shell profile."
