---
name: repo-hygiene
description: Monitor registered repos — ff-pull/clone when safe; auto-ignore graphify-out/; report dirty, ahead, or diverged trees. Used by schedule repo-hygiene and when asked about repo drift.
---

# Repo hygiene

```bash
source scripts/hub-root.sh
bash scripts/repo-monitor.sh          # human summary; exit 1 if attention needed
bash scripts/repo-monitor.sh --json   # machine-readable
bash scripts/repo-monitor.sh --no-fix  # report only
```

## Auto actions (safe)

- **Missing** checkout → `clone-repos.sh <name>`
- **Behind** + clean → ff-only pull
- **`graphify-out/`** → ensure `graphify-out/` is in `.gitignore`

## Never auto

- Commit / push / reset unrelated dirty trees
- Merge diverged branches

Those need `ship-work` (interactive) or the operator.

## Slack (schedules)

**One message only** on failure — paste the monitor table. Silent success if only `pulled` / `cloned` / `ok`.

## Related

- `ship-work` — finish your own edits
- `workspace-sync` — sync + graphify
- `config/repos.json` — registry
