#!/bin/bash
# slack-status.sh - Update Slack status for coding sessions
# Usage: slack-status.sh active | idle

SLACK_TOKEN="${SLACK_STATUS_TOKEN}"

if [ -z "$SLACK_TOKEN" ]; then
  echo "Error: SLACK_STATUS_TOKEN not set"
  exit 1
fi

# Configurable via environment variables
STATUS_TEXT="${CODING_STATUS_TEXT:-Auto Focus}"
STATUS_EMOJI="${CODING_STATUS_EMOJI:-:technologist:}"
EXPIRY_MINUTES="${CODING_STATUS_EXPIRY:-30}"

STATE_FILE="/tmp/.coding-status-active"

case "$1" in
  active)
    EXPIRATION=$(( $(date +%s) + EXPIRY_MINUTES * 60 ))
    touch "$STATE_FILE"
    ;;
  idle)
    STATUS_TEXT=""
    STATUS_EMOJI=""
    EXPIRATION=0
    rm -f "$STATE_FILE"
    ;;
  *)
    echo "Usage: slack-status.sh [active|idle]"
    exit 1
    ;;
esac

RESPONSE=$(curl -s -X POST "https://slack.com/api/users.profile.set" \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"profile\": {
      \"status_text\": \"$STATUS_TEXT\",
      \"status_emoji\": \"$STATUS_EMOJI\",
      \"status_expiration\": $EXPIRATION
    }
  }")

if echo "$RESPONSE" | grep -q '"ok":true'; then
  echo "Status updated: $1"
else
  echo "Failed to update status: $RESPONSE"
  exit 1
fi
