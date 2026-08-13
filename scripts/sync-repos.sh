#!/usr/bin/env bash
# Fast-forward sync sibling repos listed in config/repos.json.
# Usage: sync-repos.sh [repo-name]
# Aborts a repo if dirty or diverged (never force-reset).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT}/config/repos.json"
FILTER="${1:-}"
ASKPASS="${ROOT}/scripts/git-askpass-github.sh"
TOKEN_FILE="${HUB_GITHUB_TOKEN_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/agent-hub/github.token}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required" >&2
  exit 1
fi

expand() {
  local p="$1"
  p="${p/#\~/$HOME}"
  echo "$p"
}

git_auth_env() {
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then
    return 0
  fi
  if [[ -x "$ASKPASS" && -f "$TOKEN_FILE" ]]; then
    export GIT_ASKPASS="$ASKPASS"
    export GIT_TERMINAL_PROMPT=0
  fi
}
git_auth_env

count="$(jq '.repos | length' "$CONFIG")"
ok=0
fail=0

for i in $(seq 0 $((count - 1))); do
  name="$(jq -r ".repos[$i].name" "$CONFIG")"
  if [[ -n "$FILTER" && "$name" != "$FILTER" ]]; then
    continue
  fi
  path="$(expand "$(jq -r ".repos[$i].path" "$CONFIG")")"
  if [[ ! -d "$path/.git" ]]; then
    while IFS= read -r alt; do
      [[ -z "$alt" ]] && continue
      ap="$(expand "$alt")"
      if [[ -d "$ap/.git" ]]; then
        path="$ap"
        break
      fi
    done < <(jq -r ".repos[$i].altPaths // [] | .[]" "$CONFIG")
  fi
  echo "==> $name ($path)"
  if [[ ! -d "$path/.git" ]]; then
    echo "  SKIP: not a git checkout (run scripts/clone-repos.sh)"
    fail=$((fail + 1))
    continue
  fi
  (
    cd "$path"
    if [[ -n "$(git status --porcelain)" ]]; then
      echo "  ABORT: dirty working tree"
      exit 2
    fi
    if [[ -n "${GIT_ASKPASS:-}" ]]; then
      git -c credential.helper= fetch --quiet origin
    else
      git fetch --quiet origin
    fi
    branch="$(git rev-parse --abbrev-ref HEAD)"
    if [[ "$branch" == "HEAD" ]]; then
      echo "  ABORT: detached HEAD"
      exit 2
    fi
    upstream="origin/${branch}"
    if ! git rev-parse --verify "$upstream" >/dev/null 2>&1; then
      echo "  ABORT: no upstream $upstream"
      exit 2
    fi
    local_ahead="$(git rev-list --count "${upstream}..HEAD")"
    remote_ahead="$(git rev-list --count "HEAD..${upstream}")"
    if [[ "$local_ahead" -gt 0 && "$remote_ahead" -gt 0 ]]; then
      echo "  ABORT: diverged (local+$local_ahead remote+$remote_ahead)"
      exit 2
    fi
    if [[ "$remote_ahead" -gt 0 ]]; then
      git merge --ff-only "$upstream"
      echo "  OK: ff-only +$remote_ahead"
    else
      echo "  OK: already up to date"
    fi
  ) && ok=$((ok + 1)) || fail=$((fail + 1))
done

if [[ -n "$FILTER" && "$ok" -eq 0 && "$fail" -eq 0 ]]; then
  echo "no repo matched: $FILTER" >&2
  exit 1
fi

echo "sync done: ok=$ok fail=$fail"
[[ "$fail" -eq 0 ]]
