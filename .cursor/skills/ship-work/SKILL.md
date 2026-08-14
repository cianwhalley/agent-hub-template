---
name: ship-work
description: After editing any registered repo, ff-pull then commit and push on the default branch (or report blockers).
---

# Ship work (multi-repo)

**Default:** do not leave dirty trees. If you edited files this turn, run this skill before ending.

## Policy

Stay on the default branch unless the operator asked for a branch.

| Repo | Ship path |
|------|-----------|
| This hub | `git pull --ff-only` → commit on default → push |
| Siblings in `config/repos.json` | Same |
| Secrets / vault / infra | Commit OK; **ask the operator** before push if it changes live host units or secrets |

Never force-push. Never commit `.env`, `*.token`, `credentials/`, or the contents of `graphify-out/` (do commit `.gitignore` lines that ignore `graphify-out/`).

## Steps (per repo you touched)

```bash
source scripts/hub-root.sh
bash scripts/sync-repos.sh <name>   # must be clean first; if YOU dirtied it, skip sync
```

1. `git status` / `git diff` — confirm only intended files
2. Confirm you are on the default branch. Do not `checkout -b` unless asked.
3. `git pull --ff-only`
4. `git add` relevant paths
5. Commit with a short why-focused message (HEREDOC)
6. `git push origin HEAD`
7. If `gh` is missing or auth fails → tell the operator

## Blockers (do not force)

- Diverged from origin
- Dirty tree you did not create
- Hook/CI failure after push
