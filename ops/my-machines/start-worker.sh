#!/usr/bin/env bash
# Systemd-friendly launcher for a My Machines worker on this hub.
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
ENV_FILE="${HOME}/.config/agent-vault/worker.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi
: "${AGENT_VAULT_ADDR:=http://127.0.0.1:14321}"
export AGENT_VAULT_ADDR
unset AGENT_VAULT_VAULT || true

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "CURSOR_API_KEY missing in $ENV_FILE — add a personal key from https://cursor.com/dashboard/api" >&2
  exit 1
fi
export CURSOR_API_KEY

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="${WORKER_NAME:-my-vps}"

# One worker per hub. Point this at the Cloud checkout (~/cursor-workspace/<hub>).
# A second --worker-dir does not add a My Machines picker row.
exec agent worker \
  --name "$NAME" \
  --worker-dir "$ROOT" \
  --idle-release-timeout 0 \
  start
