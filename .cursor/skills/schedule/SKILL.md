---
name: schedule
description: List, add, pause, resume, or force-run hub scheduled jobs via schedules/registry.yaml. Use when the user asks to automate, schedule, cron, or pause a recurring task.
---

# Schedule (registry)

Recurring work lives in `schedules/registry.yaml`. A **VPS systemd timer** (`ops/tick/`, every 15m) runs `schedules/run-tick.sh`: cheap due-check, then headless `agent -p` only when needed. Slack via `schedules/slack-post.sh`. **Do not** create Cursor Automations per job (Cloud cannot reach the VPS body on personal plans).

## Commands

```bash
cd "$HUB_ROOT"
node schedules/due.mjs                 # what would run this bucket
node schedules/force.mjs <id>          # due on next tick
node schedules/force.mjs <id> off
node schedules/record.mjs <id> ok      # usually done by the tick
```

## Edit registry

| Ask | Action |
|-----|--------|
| List jobs | Show ids, cron, enabled, slack from `registry.yaml` |
| Schedule X | Add job: `id`, `enabled: true`, `cron` (5-field), `skill`, `slack`, optional `prompt` |
| Pause / resume | `enabled: false` / `true` |
| Run now | `node schedules/force.mjs <id>` or execute prompt in chat |
| Change cadence | Edit `cron` |

Git: feature branch → PR. On the worker: `git pull --ff-only` before edit; don't force dirty trees.

## Cron tips

- Host timezone = the VPS
- Tick is every 15m — prefer cron minutes `0`, `15`, `30`, `45`
- `slack`: `on_fail` | `always` | `never`

See also: `.cursor/skills/my-machines/SKILL.md` (one worker per hub).
