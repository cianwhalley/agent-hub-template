# My Machines worker

Run Cursor Cloud / IDE / iOS tool calls on this machine, against **this hub**.

Docs: [My Machines](https://cursor.com/docs/cloud-agent/self-hosted-guides/my-machines).

## Install

1. Personal API key from [Cursor Dashboard → API Keys](https://cursor.com/dashboard/api).
2. `~/.config/agent-vault/worker.env` (mode 600):

```bash
echo 'CURSOR_API_KEY=…' >> ~/.config/agent-vault/worker.env
chmod 600 ~/.config/agent-vault/worker.env
```

3. Edit `ops/my-machines/start-worker.sh` (`WORKER_NAME`, hub path) or export env, then:

```bash
mkdir -p ~/.config/systemd/user
HUB="$HOME/cursor-workspace/your-hub"   # Cloud checkout — not the Slack tree
sed "s|%h/your-hub|$HUB|g" "$HUB/ops/my-machines/agent-hub-worker.service" \
  > ~/.config/systemd/user/agent-hub-worker.service
loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable --now agent-hub-worker
```

4. Confirm at [cursor.com/agents](https://cursor.com/agents).

**One worker per hub.** Point `--worker-dir` at the Cloud checkout (`~/cursor-workspace/<hub>`). Slack + tick use `~/slack-workspace/<hub>` — same remote, different tree. Sibling product repos live under `config/repos.json` on disk; do not add them as extra `--worker-dir` roots expecting separate My Machines rows (Cursor registers one git remote per worker). See `.cursor/skills/my-machines/SKILL.md`.

Slack `WORKSPACE` should be the Slack hub path. Cloud recipes use `worker=<name> repo=<github-owner/hub>`. See [cursor-slack-bridge docs/my-machines.md](https://github.com/cianwhalley/cursor-slack-bridge/blob/main/docs/my-machines.md).
