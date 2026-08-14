---
name: my-machines
description: Run Cursor Cloud / IDE on a My Machines worker. Use when setting --worker-dir, picking Remote Machines, or when a second repo is missing from the machine list.
---

# Cloud / My Machines

Workers run as **`cursor-agent`** (no sudo) with `--worker-dir ~/cursor-workspace/<hub>`. Slack + tick use `~/slack-workspace/<hub>`. Same remotes, different trees. See `.cursor/rules/faces.mdc`.

One worker per hub. Cursor registers **one git remote per worker**; a second `--worker-dir` does not add a picker row.

Do not start a worker as the admin/sudo user. Do not start a worker on the laptop if the body already lives on a VPS.

## See also

- `ops/my-machines/README.md`
- [My Machines](https://cursor.com/docs/cloud-agent/self-hosted-guides/my-machines)
