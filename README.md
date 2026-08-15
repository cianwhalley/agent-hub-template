# agent-hub-template

A Cursor **hub**: the agent’s brain on disk. Clone it, make it yours, point Slack and [My Machines](https://cursor.com/docs/cloud-agent/self-hosted-guides/my-machines) at the same path.

This is not an LLM framework. Cursor is the model and the harness. The hub is `SOUL.md`, skills, rules, and a registry of sibling git checkouts the agent is allowed to touch.

Pair with **[cursor-slack-bridge](https://github.com/cianwhalley/cursor-slack-bridge)** (≥ **v0.1.1**) if you want Slack to be another face of this same workspace. That release fixes a Slack double-delivery quirk where one `@mention` looked like a queued follow-up (“Still working…”).

## Why a hub

Cursor Cloud Agents are great at one GitHub repo. An operator often needs **many** checkouts on one machine: docs, backends, a personal wiki. Put them in `config/repos.json`. The agent (Slack or IDE) ff-pulls them, edits, and opens PRs. A scheduled `repo-hygiene` job keeps trees current so neither face goes stale.

```text
~/slack-workspace/your-hub     ← Slack WORKSPACE + tick
~/cursor-workspace/your-hub    ← My Machines --worker-dir (picker)
~/work/you/example-app         ← sibling from repos.json
```

**One worker per hub.** Siblings are on disk via `repos.json`, not extra `--worker-dir` roots. See [ops/my-machines/README.md](ops/my-machines/README.md).

Two Slack bots = two hub clones (ops vs family). See the bridge’s [workspaces](https://github.com/cianwhalley/cursor-slack-bridge/blob/main/docs/workspaces.md) doc.

## Quick start

```bash
git clone https://github.com/cianwhalley/agent-hub-template.git ~/slack-workspace/your-hub
cd ~/slack-workspace/your-hub
# edit SOUL.md, USER.md, config/repos.json
bash scripts/clone-repos.sh
```

Then:

1. Cursor: open this folder, or start a My Machines worker (`ops/my-machines/`).
2. Slack: set `WORKSPACE` to this path in [cursor-slack-bridge](https://github.com/cianwhalley/cursor-slack-bridge).
3. Optional tick: `ops/tick/` + `schedules/registry.yaml` (ships `repo-hygiene` only). Per-job Cursor model via optional `model:` — see [schedules/README.md](schedules/README.md).

## Layout

| Path | Role |
|------|------|
| `SOUL.md` | Who the agent is |
| `AGENTS.md` | How to operate this hub |
| `USER.md` | Who you are (keep private facts here, not in git if needed) |
| `MEMORY.md` + `memory/` | Durable notes |
| `config/repos.json` | Sibling registry |
| `scripts/` | clone / sync / monitor / graphify |
| `.cursor/skills/` | repo-hygiene, ship-work, workspace-sync, schedule, my-machines |
| `.cursor/rules/` | always-on git + Graphify hygiene |
| `schedules/` | Optional VPS tick (no LLM when idle) |
| `ops/` | systemd units for worker + tick |

## Hygiene contract

- Start of turn: `bash scripts/repo-monitor.sh`
- Before focusing a sibling: `bash scripts/sync-repos.sh <name>`
- After **your** edits: follow `.cursor/skills/ship-work/SKILL.md` (branch → PR)
- Never force-reset a dirty or diverged tree you did not create
- Never commit `graphify-out/`
- Cloud/VPS host tools: `bash scripts/ensure-agent-tools.sh` (via `.cursor/environment.json`) — installs musl `gws` on Ubuntu 22.04; do not use `npm i -g @googleworkspace/cli` there

GitHub auth: SSH key on the VPS, or `HUB_GITHUB_TOKEN_FILE` (default `~/.config/agent-hub/github.token`) for HTTPS.

## License

[MIT](LICENSE)
