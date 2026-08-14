# Agent hub

This directory is the agent’s workspace. Read [SOUL.md](SOUL.md) and [USER.md](USER.md) first. Durable facts live in [MEMORY.md](MEMORY.md) and `memory/`.

## Faces

| Face | How |
|------|-----|
| Laptop IDE | The clone you opened. Edit + push git. Not the VPS tree. |
| Slack + tick | `cursor-agent` `~/slack-workspace/<hub>` |
| Cloud | `cursor-agent` `~/cursor-workspace/<hub>` via My Machines `worker=… repo=…` ([skill](.cursor/skills/my-machines/SKILL.md)) |

Same remotes. **Different checkouts.** Agents have no sudo. See `.cursor/rules/faces.mdc`.

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
