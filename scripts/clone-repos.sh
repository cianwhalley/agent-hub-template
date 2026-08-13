#!/usr/bin/env bash
# Clone missing sibling repos from config/repos.json.
# Usage: clone-repos.sh [repo-name]
# Prefers SSH if `ssh -T git@github.com` works; else HTTPS via git-askpass-github.sh.
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

use_ssh=0
if ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then
  use_ssh=1
fi

count="$(jq '.repos | length' "$CONFIG")"
ok=0
fail=0
skip=0

for i in $(seq 0 $((count - 1))); do
  name="$(jq -r ".repos[$i].name" "$CONFIG")"
  org="$(jq -r ".repos[$i].org // \"\"" "$CONFIG")"
  if [[ -n "$FILTER" && "$name" != "$FILTER" ]]; then
    continue
  fi
  path="$(expand "$(jq -r ".repos[$i].path" "$CONFIG")")"
  if [[ "$org" == "hub" ]] || [[ "$path" == "$ROOT" ]]; then
    echo "==> $name (hub — skip clone)"
    skip=$((skip + 1))
    continue
  fi
  branch="$(jq -r ".repos[$i].defaultBranch // \"main\"" "$CONFIG")"
  echo "==> $name ($path)"
  if [[ -d "$path/.git" ]]; then
    echo "  SKIP: already cloned"
    skip=$((skip + 1))
    continue
  fi
  mkdir -p "$(dirname "$path")"
  if [[ "$use_ssh" -eq 1 ]]; then
    url="$(jq -r ".repos[$i].git" "$CONFIG")"
    if git clone --branch "$branch" --single-branch "$url" "$path"; then
      echo "  OK: cloned (ssh)"
      ok=$((ok + 1))
    else
      echo "  FAIL: ssh clone"
      fail=$((fail + 1))
    fi
  else
    if [[ ! -f "$TOKEN_FILE" ]]; then
      echo "  FAIL: need SSH auth or $TOKEN_FILE" >&2
      fail=$((fail + 1))
      continue
    fi
    url="$(jq -r ".repos[$i].https // empty" "$CONFIG")"
    if [[ -z "$url" ]]; then
      url="$(jq -r ".repos[$i].git" "$CONFIG" | sed 's#git@github.com:#https://github.com/#')"
    fi
    if GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0 \
      git -c credential.helper= clone --branch "$branch" --single-branch "$url" "$path"; then
      git -C "$path" remote set-url origin "$url"
      echo "  OK: cloned (https)"
      ok=$((ok + 1))
    else
      echo "  FAIL: https clone"
      rm -rf "$path"
      fail=$((fail + 1))
    fi
  fi
done

echo "clone done: ok=$ok skip=$skip fail=$fail"
[[ "$fail" -eq 0 ]]
