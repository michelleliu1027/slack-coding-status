#!/bin/bash
# install.sh - Install slack-coding-status

set -e

INSTALL_DIR="$HOME/.local/bin"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Slack Coding Status Installer ==="
echo ""

# 1. Check for token
if [ -z "$SLACK_STATUS_TOKEN" ]; then
  echo "SLACK_STATUS_TOKEN not found in environment."
  echo ""
  echo "To get your token:"
  echo "  1. Go to https://api.slack.com/apps and create a new app"
  echo "  2. Add 'users.profile:write' under User Token Scopes"
  echo "  3. Install the app to your workspace"
  echo "  4. Copy the 'User OAuth Token' (starts with xoxp-)"
  echo ""
  read -p "Paste your Slack token here: " TOKEN
  echo ""
  echo "Add this to your shell profile (~/.zshrc or ~/.bashrc):"
  echo "  export SLACK_STATUS_TOKEN=\"$TOKEN\""
  echo ""
  read -p "Want me to add it to ~/.zshrc? [y/N] " ADD_TO_SHELL
  if [[ "$ADD_TO_SHELL" =~ ^[Yy]$ ]]; then
    echo "" >> ~/.zshrc
    echo "# Slack coding status" >> ~/.zshrc
    echo "export SLACK_STATUS_TOKEN=\"$TOKEN\"" >> ~/.zshrc
    echo "Added to ~/.zshrc"
  fi
else
  TOKEN="$SLACK_STATUS_TOKEN"
  echo "Found SLACK_STATUS_TOKEN in environment."
fi

echo ""

# 2. Install scripts
mkdir -p "$INSTALL_DIR"
cp "$REPO_DIR/slack-status.sh" "$INSTALL_DIR/"
cp "$REPO_DIR/coding-detect.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/slack-status.sh" "$INSTALL_DIR/coding-detect.sh"
echo "Installed scripts to $INSTALL_DIR"

# 3. Install LaunchAgent (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  PLIST_DIR="$HOME/Library/LaunchAgents"
  PLIST_FILE="$PLIST_DIR/com.coding-status.plist"
  mkdir -p "$PLIST_DIR"

  cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.coding-status</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/coding-detect.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>SLACK_STATUS_TOKEN</key>
        <string>$TOKEN</string>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/coding-status.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/coding-status.log</string>
</dict>
</plist>
EOF

  launchctl unload "$PLIST_FILE" 2>/dev/null || true
  launchctl load "$PLIST_FILE"
  echo "Installed and started LaunchAgent (runs every 5 minutes)"
fi

echo ""
echo "=== Done! ==="
echo ""
echo "Your Slack status will now automatically update when you're coding."
echo ""
echo "Manual usage:"
echo "  slack-status.sh active   # Set coding status"
echo "  slack-status.sh idle     # Clear status"
echo ""
echo "Optional: Add Claude Code hook for instant updates."
echo "See README.md for details."
