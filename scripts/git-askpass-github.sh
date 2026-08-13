#!/usr/bin/env bash
# GIT_ASKPASS helper — prints a GitHub PAT from a local file (never logs it).
# Usage: GIT_ASKPASS=scripts/git-askpass-github.sh git clone https://github.com/...
set -euo pipefail
TOKEN_FILE="${HUB_GITHUB_TOKEN_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/agent-hub/github.token}"
if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "git-askpass-github: missing $TOKEN_FILE" >&2
  exit 1
fi
case "${1:-}" in
  *Username*) echo "x-access-token" ;;
  *) tr -d '[:space:]' < "$TOKEN_FILE" ;;
esac
