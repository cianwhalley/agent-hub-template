# Hub tick (VPS systemd)

Cursor Automations cannot target My Machines on personal plans. The clock lives on the VPS:

1. Timer every 15m → `schedules/run-tick.sh` (aborts if hub dirty; else `git pull --ff-only`)
2. `due.mjs` empty → exit (no LLM)
3. Else → one `agent -p` per **model group** (registry optional `model:`; default `AGENT_MODEL`); Slack via `schedules/slack-post.sh`

Unit defaults: `AGENT_MODEL=cursor-grok-4.6-medium` and `AGENT_MODEL_FALLBACK=gpt-5.6-sol-medium`. Override either per job with `model:` / `fallback_model:` (`off` disables fallback). Jobs run separately; provider/usage failures retry once. Final failure is recorded, posted directly to Slack, and exits non-zero.

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
