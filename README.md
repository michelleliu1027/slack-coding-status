# slack-coding-status

Automatically update your Slack status when you're coding. Your teammates will know you're in deep work and shouldn't be interrupted.

![Demo](demo.png)

## How it works

- **App detection**: Polls every 5 minutes to check if your frontmost app is a code editor or terminal
- **Claude Code hook**: Instantly sets your status when you start a conversation with Claude Code
- **Auto-clear**: Removes your status after 15 minutes of inactivity (configurable)
- **Safety net**: Status has a 30-minute expiration in case your machine sleeps

## Supported apps

VSCode, Cursor, Windsurf, Terminal, iTerm2, Warp, Alacritty, kitty (and any app you add via `CODING_APPS` env var)

## Quick start

### 1. Create a Slack App

1. Go to [https://api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → From scratch
2. Go to **OAuth & Permissions** → Under **User Token Scopes**, add `users.profile:write`
3. Click **Install to Workspace** → Authorize
4. Copy the **User OAuth Token** (starts with `xoxp-`)

### 2. Install

```bash
git clone https://github.com/michelleliu1027/slack-coding-status.git
cd slack-coding-status
export SLACK_STATUS_TOKEN="xoxp-your-token-here"
./install.sh
```

The installer will:
- Copy scripts to `~/.local/bin/`
- Set up a macOS LaunchAgent that runs every 5 minutes
- Optionally save your token to `~/.zshrc`

### 3. (Optional) Claude Code integration

For instant status updates when using [Claude Code](https://docs.anthropic.com/en/docs/claude-code), add hooks to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.local/bin/slack-status.sh active",
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.local/bin/slack-status.sh active"
          }
        ]
      }
    ]
  }
}
```

See `claude-hook-example.json` for the full snippet.

## Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SLACK_STATUS_TOKEN` | (required) | Your Slack User OAuth Token |
| `CODING_STATUS_TEXT` | `Vibe coding` | Status text shown in Slack |
| `CODING_STATUS_EMOJI` | `:technologist:` | Status emoji |
| `CODING_STATUS_EXPIRY` | `30` | Auto-expiry in minutes |
| `CODING_IDLE_THRESHOLD` | `900` | Seconds of inactivity before clearing (default 15 min) |
| `CODING_APPS` | `Code,Code - Insiders,Cursor,...` | Comma-separated list of app names to detect |

## Manual usage

```bash
slack-status.sh active   # Set coding status
slack-status.sh idle     # Clear status
```

## Uninstall

```bash
./uninstall.sh
```

## How it looks

When active, your Slack profile shows:

> 🧑‍💻 Vibe coding · Until 1:30 PM

## Platform support

- **macOS**: Full support (LaunchAgent + app detection via AppleScript)
- **Linux**: Coming soon (systemd timer + xdotool)

## License

MIT
