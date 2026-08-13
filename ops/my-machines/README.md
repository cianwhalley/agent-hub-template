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
HUB="$HOME/workspaces/your-hub"
sed "s|%h/your-hub|$HUB|g" "$HUB/ops/my-machines/agent-hub-worker.service" \
  > ~/.config/systemd/user/agent-hub-worker.service
loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable --now agent-hub-worker
```

4. Confirm at [cursor.com/agents](https://cursor.com/agents).

Slack `WORKSPACE` should be this same directory. See [cursor-slack-bridge docs/my-machines.md](https://github.com/zenmindhacker/cursor-slack-bridge/blob/main/docs/my-machines.md).
