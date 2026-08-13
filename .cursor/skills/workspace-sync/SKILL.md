---
name: workspace-sync
description: ff-only sync registered repos and rebuild Graphify merge.
---

# Workspace sync

```bash
bash scripts/repo-monitor.sh        # prefer — pulls + reports drift
bash scripts/sync-repos.sh          # all (abort on dirty)
bash scripts/sync-repos.sh <name>   # one
bash scripts/graphify-rebuild.sh
```

Abort dirty/diverged without force. Never commit `graphify-out/`.
If **you** left dirt, use `ship-work` instead of sync.
