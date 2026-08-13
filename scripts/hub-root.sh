# Resolve hub root (skills/, schedules/, config/).
# shellcheck shell=bash
if [[ -n "${HUB_ROOT:-}" && -d "${HUB_ROOT}" ]]; then
  HUB_ROOT="$(cd "$HUB_ROOT" && pwd)"
else
  _here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  HUB_ROOT="$(cd "$_here/.." && pwd)"
fi
export HUB_ROOT
export HUB_SKILLS="${HUB_ROOT}/.cursor/skills"
