# Agent hub

This directory is the agent’s workspace. Read [SOUL.md](SOUL.md) and [USER.md](USER.md) first. Durable facts live in [MEMORY.md](MEMORY.md) and `memory/`.

## Faces

| Face | How |
|------|-----|
| Cursor IDE / web / iOS | Open this folder, or My Machines `worker=… repo=…`. Repeat `--worker-dir` for extra hubs; the picker still shows the **first** path only ([skill](.cursor/skills/my-machines/SKILL.md)). |
| Slack | [cursor-slack-bridge](https://github.com/cianwhalley/cursor-slack-bridge) `WORKSPACE` = this path |
| Tick | `schedules/run-tick.sh` on a systemd timer |

Same disk. Same rules. Same sibling repos.

## Multi-repo

Registry: [config/repos.json](config/repos.json).

```bash
source scripts/hub-root.sh
bash scripts/clone-repos.sh
bash scripts/repo-monitor.sh
```

After you edit a registered repo, follow `.cursor/skills/ship-work/SKILL.md`. Do not leave a dirty tree.

## Schedules

[schedules/registry.yaml](schedules/registry.yaml) is the source of truth. Cursor Automations on personal plans cannot target My Machines — use the VPS timer. See `.cursor/skills/schedule/SKILL.md`.

## Secrets

Do not print tokens. Optional loopback secrets proxy: see the bridge [credentials doc](https://github.com/cianwhalley/cursor-slack-bridge/blob/main/docs/credentials.md).
