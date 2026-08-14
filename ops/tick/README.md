# Hub tick (VPS systemd)

Cursor Automations cannot target My Machines on personal plans. The clock lives on the VPS:

1. Timer every 15m → `schedules/run-tick.sh`
2. `due.mjs` empty → exit (no LLM)
3. Else → `agent -p` with due jobs; Slack via `schedules/slack-post.sh`

## Install

As the user who should run ticks (often the same user as My Machines):

```bash
mkdir -p ~/.config/systemd/user
HUB="$HOME/slack-workspace/your-hub"   # this clone
sed "s|%h/your-hub|$HUB|g" "$HUB/ops/tick/agent-hub-tick.service" \
  > ~/.config/systemd/user/agent-hub-tick.service
cp "$HUB/ops/tick/agent-hub-tick.timer" ~/.config/systemd/user/
loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable --now agent-hub-tick.timer
```

Put `CURSOR_API_KEY` in `~/.config/agent-vault/worker.env` (mode 600) or `HUB_TICK_ENV_FILE`.

Slack: copy or share the bridge instance env (`~/.config/cursor-slack/main.env`) and set `SLACK_ALERT_CHANNEL` (or `ALERT_CHANNELS` in that file).
