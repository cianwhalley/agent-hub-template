#!/usr/bin/env bash
# Cheap due-check; wake headless agent only when work is due.
# Intended for systemd timer every 15 minutes.
set -euo pipefail

export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${HUB_TICK_ENV_FILE:-$HOME/.config/agent-vault/worker.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "run-tick: CURSOR_API_KEY missing (expected in $ENV_FILE)" >&2
  exit 1
fi

DUE_JSON="$(node schedules/due.mjs)"
DUE_TRIMMED="$(printf '%s' "$DUE_JSON" | tr -d '[:space:]')"
if [[ "$DUE_TRIMMED" == "[]" ]]; then
  echo "run-tick: nothing due — idle exit"
  exit 0
fi

echo "run-tick: due jobs — waking agent"
PROMPT="$(cat schedules/tick-prompt.txt)
${DUE_JSON}
"

LOCK="${XDG_RUNTIME_DIR:-/tmp}/agent-hub-tick.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "run-tick: another tick is running — skip" >&2
  exit 0
fi

agent -p --force --trust --workspace "$ROOT" --output-format text "$PROMPT"
echo "run-tick: agent finished"
