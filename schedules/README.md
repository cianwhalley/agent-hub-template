# Hub schedule registry

Source of truth for recurring work. **Clock = VPS systemd** (`ops/tick/`, every 15m), not Cursor Automations (Automations cannot target My Machines on personal plans).

## Flow

1. Timer → [`run-tick.sh`](run-tick.sh)
2. [`due.mjs`](due.mjs) → `[]` → exit (no LLM)
3. Else → `agent -p` with [`tick-prompt.txt`](tick-prompt.txt)
4. Slack → [`slack-post.sh`](slack-post.sh) (same bot token as cursor-slack-bridge)

## Files

| Path | Purpose |
|------|---------|
| `registry.yaml` | Job definitions (git) |
| `due.mjs` | Cheap due-check → JSON |
| `record.mjs` / `force.mjs` | State updates / force next tick |
| `run-tick.sh` | Dispatcher for systemd |
| `slack-post.sh` | Post + `mark-participated` |
| `state.json` / `runs.log` | Local only (gitignored) |

Seeded job: `repo-hygiene`. `graphify-rebuild` is present but disabled.

## Install timer

See [`ops/tick/README.md`](../ops/tick/README.md).
