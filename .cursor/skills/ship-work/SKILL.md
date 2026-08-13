---
name: ship-work
description: After editing any registered repo, sync then commit and open a PR (or report blockers). Use when finishing code changes, or when the user says ship, commit, push, PR.
---

# Ship work (multi-repo)

**Default:** do not leave dirty trees. If you edited files this turn, run this skill before ending.

## Policy

| Repo | Ship path |
|------|-----------|
| This hub | feature branch → PR → `gh pr merge --auto` when checks exist. Direct push to the default branch only if the operator explicitly says so. |
| Siblings in `config/repos.json` | Always feature branch → PR |
| Secrets / vault / infra | Commit OK; **ask the operator** before merge |

Never force-push. Never commit `.env`, `*.token`, `credentials/`, or the contents of `graphify-out/` (do commit `.gitignore` lines that ignore `graphify-out/`).

## Steps (per repo you touched)

```bash
source scripts/hub-root.sh
bash scripts/sync-repos.sh <name>   # must be clean first; if YOU dirtied it, skip sync
```

1. `git status` / `git diff` — confirm only intended files
2. `git checkout -b <prefix>/<short-topic>` from up-to-date default branch
3. `git add` relevant paths
4. Commit with a short why-focused message (HEREDOC)
5. `git push -u origin HEAD`
6. `gh pr create` + `gh pr merge --auto` (skip auto-merge for secrets/infra)
7. If `gh` is missing or auth fails → tell the operator the branch name

## Multi-repo turns

Ship **each** dirty registered repo, not only the hub. After merges: `bash scripts/sync-repos.sh` (or wait for `repo-hygiene`).

## Blockers (do not force)

- Diverged from origin
- Dirty tree you did not create
- Hook/CI failure after push
