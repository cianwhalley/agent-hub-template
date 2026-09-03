# Hub schedule registry

Source of truth for recurring work. **Clock = VPS systemd** (`ops/tick/`, every 15m), not Cursor Automations (Automations cannot target My Machines on personal plans).

## Flow

1. Timer → [`run-tick.sh`](run-tick.sh) (dirty hub → abort; else ff-pull hub)
2. [`due.mjs`](due.mjs) → `[]` → exit (no LLM)
3. Else → one isolated `agent -p` per job with [`tick-prompt.txt`](tick-prompt.txt); provider/usage failure retries once on the fallback
4. Slack → [`slack-post.sh`](slack-post.sh) (same bot token as cursor-slack-bridge)

## Per-job models

Optional `model:` / `fallback_model:` on each job in [`registry.yaml`](registry.yaml):

```yaml
- id: morning-brief
  enabled: true
  cron: "0 7 * * *"
  skill: morning-brief
  slack: always
  model: cursor-grok-4.6-high   # judgment-heavy; prefer non-fast for ticks
  fallback_model: gpt-5.6-sol-medium
  prompt: |
    …
```

- Omit `model` → tick default `AGENT_MODEL` (unit sets `cursor-grok-4.6-medium`)
- Omit `fallback_model` → `AGENT_MODEL_FALLBACK` (unit sets `gpt-5.6-sol-medium`); `off` disables it
- Prefer **non-fast** ids for background work; `run-tick.sh` strips a trailing `-fast`
- Due jobs run separately so one provider failure cannot strand unrelated work
- If both models fail, the runner records `fail`, posts directly to Slack, continues other due jobs, then exits non-zero
- Keep Slack interactive on high-fast via the bridge env, not the tick unit

## Files

| Path | Purpose |
|------|---------|
| `registry.yaml` | Job definitions (git) |
| `due.mjs` | Cheap due-check → JSON (includes primary/fallback overrides) |
| `group-due-models.mjs` | Prepare one isolated model pair per due job |
| `record.mjs` / `force.mjs` | State updates / force next tick |
| `run-tick.sh` | Dispatcher for systemd |
| `slack-post.sh` | Post + `mark-participated` |
| `state.json` / `runs.log` | Local only (gitignored) |

Seeded job: `repo-hygiene`. `graphify-rebuild` is present but disabled.

## Install timer

See [`ops/tick/README.md`](../ops/tick/README.md).
