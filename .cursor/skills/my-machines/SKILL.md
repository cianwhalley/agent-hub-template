---
name: my-machines
description: Run Cursor Cloud / IDE on a My Machines worker. Use when setting --worker-dir, sharing one worker across hubs, picking Remote Machines, or when a second repo is missing from the machine list.
---

# Cloud / My Machines

Worker install: `ops/my-machines/`. Trigger with `worker=<name> repo=<github-owner/hub>`.

`--worker-dir` is **repeatable** (up to 20). The **first** path is assignment identity and what the IDE/dashboard shows. Extra roots register git remotes for routing; Cursor does **not** add a row per repo.

If a second hub is missing from **Run on → Remote Machines**, pick the existing worker (named after the first checkout) rather than adding a second `--name`. Confirm with `agent worker start --verbose` (`workspacePaths` / `x-repository-urls`).

Do not start a worker on the laptop if the body already lives on a VPS.

## See also

- `ops/my-machines/README.md`
- [My Machines](https://cursor.com/docs/cloud-agent/self-hosted-guides/my-machines)
