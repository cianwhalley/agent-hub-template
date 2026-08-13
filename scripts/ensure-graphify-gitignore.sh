#!/usr/bin/env bash
# Ensure graphify-out/ is ignored in a repo. Idempotent.
# Usage: ensure-graphify-gitignore.sh <repo-path>
# Prints: ok | updated | exclude_only | skip
set -euo pipefail

dir="${1:-}"
if [[ -z "$dir" || ! -d "$dir/.git" ]]; then
  echo "skip"
  exit 0
fi

pattern='graphify-out/'
has_pattern() {
  local f="$1"
  [[ -f "$f" ]] && grep -qE '^(/)?graphify-out(/|\*|$)' "$f"
}

append_pattern() {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  if [[ -f "$f" ]]; then
    [[ -s "$f" && "$(tail -c1 "$f" | wc -l)" -eq 0 ]] || printf '\n' >>"$f"
    printf '%s\n' "$pattern" >>"$f"
  else
    printf '%s\n' "$pattern" >"$f"
  fi
}

exclude="$dir/.git/info/exclude"
gi="$dir/.gitignore"
excl_ok=0
gi_ok=0
changed_gi=0

if has_pattern "$exclude"; then
  excl_ok=1
else
  append_pattern "$exclude"
fi

if has_pattern "$gi"; then
  gi_ok=1
else
  append_pattern "$gi"
  changed_gi=1
fi

if [[ "$changed_gi" -eq 1 ]]; then
  echo "updated"
elif [[ "$gi_ok" -eq 1 && "$excl_ok" -eq 1 ]]; then
  echo "ok"
else
  echo "exclude_only"
fi
