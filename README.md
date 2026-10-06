# slack-coding-status

Automatically update your Slack status when you're coding. Your teammates will know you're in deep work and shouldn't be interrupted.

![Demo](demo.png)

## How it works

Polls every 20 seconds and sets your status only when **both** are true:

1. Your frontmost app is a coding or AI app, and
2. You're actually at your desk — screen unlocked and keyboard/mouse used in the last 5 minutes

That second condition is what makes the status disappear promptly:

- **Lock your screen or close the lid** → status clears on the next poll (~20s)
- **Walk away with your editor still frontmost** → clears after 5 minutes of no input
- **Switch to Slack or a browser briefly** → status holds for a 60s grace period, so it doesn't flicker
- **Safety net**: status also carries a 15-minute Slack expiry, in case the agent stops running

Slack is only called when the status actually changes, so a 20s poll costs one `ioreg` and one
`lsappinfo` call — no API traffic while nothing changes.

## Supported apps

**AI apps**: ChatGPT / Codex desktop, Claude desktop, Cursor, Windsurf
**Editors & terminals**: VSCode, Zed, Terminal, iTerm2, Warp, Alacritty, kitty, Ghostty, WezTerm

Apps are matched by bundle ID (`CODING_BUNDLE_IDS`) or display name (`CODING_APPS`). To find an
app's bundle ID, focus it and run `lsappinfo info -only bundleid "$(lsappinfo front)"`.

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

To count a long-running Claude Code session as activity even while you're reading its output,
add this to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "date +%s > /tmp/.coding-last-active",
            "async": true
          }
        ]
      }
    ]
  }
}
```

The hook only refreshes the activity timestamp — it deliberately does **not** call
`slack-status.sh active` directly. A hook that sets the status itself will pin it on while you're
away from your desk, since agent sessions keep firing tool calls with nobody watching.

## Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SLACK_STATUS_TOKEN` | (required) | Your Slack User OAuth Token |
| `CODING_STATUS_TEXT` | `Auto Focus` | Status text shown in Slack |
| `CODING_STATUS_EMOJI` | `:technologist:` | Status emoji |
| `CODING_STATUS_EXPIRY` | `15` | Slack-side auto-expiry, in minutes |
| `CODING_POLL_INTERVAL` | `20` | Seconds between checks (read by `install.sh`) |
| `CODING_AWAY_IDLE` | `300` | Seconds without keyboard/mouse that count as away |
| `CODING_GRACE` | `60` | Seconds to hold the status after switching to a non-coding app |
| `CODING_REFRESH` | `600` | Seconds between re-pushes, so the Slack expiry can't drop it |
| `CODING_APPS` | `Code,Cursor,ChatGPT,...` | Comma-separated app display names |
| `CODING_BUNDLE_IDS` | `com.openai.codex,...` | Comma-separated bundle IDs (more reliable than names) |

## Manual usage

```bash
slack-status.sh active    # Set coding status
slack-status.sh idle      # Clear status
coding-detect.sh --debug  # Show what it detects and would do, without calling Slack
```

`--debug` prints the frontmost app, whether it matched, your input-idle seconds, and the decision.
Use it when the status isn't behaving — most often the app just isn't in the whitelist.

## Uninstall

```bash
./uninstall.sh
```

## How it looks

When active, your Slack profile shows:

> 🧑‍💻 Auto Focus · Until 1:30 PM

## Platform support

- **macOS**: Full support. App detection uses `lsappinfo`, presence uses `ioreg`
  (`HIDIdleTime` + `kCGSSessionScreenIsLocked`). None of these need Accessibility or
  Automation permissions — AppleScript's `System Events` does, and when that permission is
  missing it fails silently and reports no frontmost app at all.
- **Linux**: Coming soon (systemd timer + xdotool)

## License

MIT
