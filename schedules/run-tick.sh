#!/usr/bin/env bash
# Cheap due-check; wake headless agent only when work is due.
# Intended for systemd timer every 15 minutes.
# cwd = this hub (--workspace "$ROOT"); --force --trust so ticks stay non-interactive.
set -euo pipefail

export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "run-tick: hub dirty — abort (will not merge over dirt)" >&2
  exit 1
fi
if ! git pull --ff-only; then
  echo "run-tick: git pull --ff-only failed — abort" >&2
  exit 1
fi

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
LOCK="${XDG_RUNTIME_DIR:-/tmp}/agent-hub-tick.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "run-tick: another tick is running — skip" >&2
  exit 0
fi

export AGENT_MODEL="${AGENT_MODEL:-cursor-grok-4.6-medium}"
export AGENT_MODEL_FALLBACK="${AGENT_MODEL_FALLBACK:-gpt-5.6-sol-medium}"
FAILED=0
while IFS= read -r group_line; do
  [[ -z "$group_line" ]] && continue
  MODEL="$(jq -r '.model' <<<"$group_line")"
  FALLBACK_MODEL="$(jq -r '.fallbackModel' <<<"$group_line")"
  JOBS_JSON="$(jq '.jobs' <<<"$group_line")"
  IDS="$(jq -r '[.[].id] | join(",")' <<<"$JOBS_JSON")"
  echo "run-tick: model=${MODEL} jobs=${IDS}"
  PROMPT="$(cat schedules/tick-prompt.txt)
${JOBS_JSON}
"
  PRIMARY_LOG="$(mktemp)"
  if agent -p --force --trust --workspace "$ROOT" --output-format text --model "$MODEL" "$PROMPT" 2>&1 | tee "$PRIMARY_LOG"; then
    rm -f "$PRIMARY_LOG"
    continue
  fi

  MODEL_FAILURE_RE='resource_exhausted|retriableerror|connection lost|out of usage|actionrequirederror|service unavailable|temporarily unavailable|model.*unavailable|provider.*degraded|overloaded|at capacity|upstream error|bad gateway|gateway timeout'
  if [[ -n "$FALLBACK_MODEL" && "$FALLBACK_MODEL" != "$MODEL" ]] &&
    grep -Eiq "$MODEL_FAILURE_RE" "$PRIMARY_LOG"; then
    echo "run-tick: primary unavailable; retrying jobs=${IDS} model=${FALLBACK_MODEL}" >&2
    FALLBACK_LOG="$(mktemp)"
    if agent -p --force --trust --workspace "$ROOT" --output-format text --model "$FALLBACK_MODEL" "$PROMPT" 2>&1 | tee "$FALLBACK_LOG"; then
      rm -f "$PRIMARY_LOG" "$FALLBACK_LOG"
      continue
    fi
    rm -f "$FALLBACK_LOG"
  fi

  rm -f "$PRIMARY_LOG"
  FAILED=1
  node schedules/record.mjs "$IDS" fail "agent models failed: primary=$MODEL fallback=${FALLBACK_MODEL:-off}" || true
  schedules/slack-post.sh "❌ *scheduled job failed* — \`${IDS}\`
Primary: \`${MODEL}\` · fallback: \`${FALLBACK_MODEL:-off}\`
Both model attempts failed (or fallback was not eligible). Inspect the tick service journal." ||
    echo "run-tick: CRITICAL — job failure Slack alert also failed" >&2
done < <(printf '%s' "$DUE_JSON" | node schedules/group-due-models.mjs)

if [[ "$FAILED" -ne 0 ]]; then
  echo "run-tick: one or more jobs failed after fallback" >&2
  exit 1
fi
echo "run-tick: agent finished"
