#!/usr/bin/env bash
# Template vault helper — set config/vault.json then customize TOKEN defaults.
set -euo pipefail

_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${AGENT_VAULT_ADDR:=http://127.0.0.1:14321}"

unset AGENT_VAULT_VAULT || true
unset AGENT_VAULT_TOKEN || true
unset AGENT_VAULT_TOKEN_FILE || true

if [[ ! -f "$_ROOT/config/vault.json" ]]; then
  echo "vault-env: missing config/vault.json — set vault + tokenFile for this hub" >&2
  return 1 2>/dev/null || exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "vault-env: jq required to read config/vault.json" >&2
  return 1 2>/dev/null || exit 1
fi

AGENT_VAULT_VAULT="$(jq -r '.vault' "$_ROOT/config/vault.json")"
TOKEN_FILE="$(jq -r '.tokenFile' "$_ROOT/config/vault.json")"
TOKEN_FILE="${TOKEN_FILE/#\~/$HOME}"
if [[ -z "$AGENT_VAULT_VAULT" || "$AGENT_VAULT_VAULT" == "REPLACE_ME" || -z "$TOKEN_FILE" ]]; then
  echo "vault-env: edit config/vault.json (vault + tokenFile)" >&2
  return 1 2>/dev/null || exit 1
fi

AGENT_VAULT_TOKEN_FILE="$TOKEN_FILE"
if [[ -f "$TOKEN_FILE" ]]; then
  AGENT_VAULT_TOKEN="$(tr -d '[:space:]' <"$TOKEN_FILE")"
fi

export AGENT_VAULT_ADDR AGENT_VAULT_VAULT AGENT_VAULT_TOKEN_FILE
if [[ -n "${AGENT_VAULT_TOKEN:-}" ]]; then
  export AGENT_VAULT_TOKEN
fi

vault_run() {
  if [[ -z "${AGENT_VAULT_TOKEN:-}" ]]; then
    echo "AGENT_VAULT_TOKEN unset and no token file at $TOKEN_FILE" >&2
    return 1
  fi
  if [[ "${1:-}" == "--" ]]; then
    shift
  fi
  agent-vault run -- "$@"
}
