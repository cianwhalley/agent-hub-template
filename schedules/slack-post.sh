#!/usr/bin/env bash
# Post mrkdwn to Slack via the same bot token as cursor-slack-bridge.
# Usage: schedules/slack-post.sh "mrkdwn text"
#        echo "text" | schedules/slack-post.sh
#
# Env:
#   SLACK_ALERT_CHANNEL  (required unless set in the env file)
#   SLACK_BOT_TOKEN      or HUB_SLACK_ENV_FILE / ~/.config/cursor-slack/main.env
#   SESSION_DB           optional; used with mark-participated.mjs
#   CURSOR_SLACK_BRIDGE  path to the bridge clone (default ~/cursor-slack-bridge)
set -euo pipefail

CHANNEL="${SLACK_ALERT_CHANNEL:-}"
if [[ -n "${HUB_SLACK_ENV_FILE:-}" ]]; then
  ENV_FILE="$HUB_SLACK_ENV_FILE"
elif [[ -f "$HOME/.config/cursor-slack/main.env" ]]; then
  ENV_FILE="$HOME/.config/cursor-slack/main.env"
else
  ENV_FILE=""
fi

if [[ -n "${1:-}" ]]; then
  TEXT="$1"
else
  TEXT="$(cat)"
fi

if [[ -z "${TEXT// }" ]]; then
  echo "slack-post: empty message" >&2
  exit 2
fi

if [[ -z "${SLACK_BOT_TOKEN:-}" ]]; then
  if [[ -z "$ENV_FILE" || ! -f "$ENV_FILE" ]]; then
    echo "slack-post: no SLACK_BOT_TOKEN and no env file" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  set -a
  eval "$(grep -E '^(SLACK_BOT_TOKEN|SESSION_DB|ALERT_CHANNELS)=' "$ENV_FILE" | head -5)"
  set +a
fi

if [[ -z "$CHANNEL" ]]; then
  CHANNEL="${ALERT_CHANNELS%%,*}"
fi
CHANNEL="${CHANNEL// /}"

if [[ -z "${SLACK_BOT_TOKEN:-}" || -z "$CHANNEL" ]]; then
  echo "slack-post: need SLACK_BOT_TOKEN and SLACK_ALERT_CHANNEL (or ALERT_CHANNELS in the env file)" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP" "${TMP}.out"' EXIT
export HUB_SLACK_TEXT="$TEXT"
export HUB_SLACK_CHANNEL="$CHANNEL"
node >>"$TMP" <<'NODE'
const payload = {
  channel: process.env.HUB_SLACK_CHANNEL,
  text: process.env.HUB_SLACK_TEXT,
  mrkdwn: true,
};
process.stdout.write(JSON.stringify(payload));
NODE

RESP="$(curl -sS -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data-binary @"$TMP")"
printf '%s' "$RESP" >"${TMP}.out"
posted="$(node -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (j.ok !== true) {
  console.error("slack-post: API error:", j.error || fs.readFileSync(process.argv[1], "utf8").slice(0, 200));
  process.exit(1);
}
if (j.channel && j.ts) process.stdout.write(j.channel + " " + j.ts);
' "${TMP}.out")"
echo "slack-post: ok${posted:+ $posted}"
if [[ -n "$posted" ]]; then
  posted_channel="${posted%% *}"
  posted_ts="${posted#* }"
  db="${SESSION_DB:-$HOME/.local/share/cursor-slack/main.db}"
  mark="${CURSOR_SLACK_BRIDGE:-$HOME/cursor-slack-bridge}/scripts/mark-participated.mjs"
  if [[ -f "$mark" ]]; then
    node "$mark" "$db" "$posted_channel" "$posted_ts" || true
  fi
fi
