#!/usr/bin/env bash
# Monitor sibling repos: ff-pull when safe; report dirty/ahead/diverged/missing.
# Exit 0 if all OK (or only auto-fixed). Exit 1 if attention needed.
# Usage: repo-monitor.sh [--json] [--no-fix]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT}/config/repos.json"
ASKPASS="${ROOT}/scripts/git-askpass-github.sh"
TOKEN_FILE="${HUB_GITHUB_TOKEN_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/agent-hub/github.token}"
JSON=0
FIX=1
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    --no-fix) FIX=0 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required" >&2
  exit 1
fi

expand() {
  local p="$1"
  p="${p/#\~/$HOME}"
  echo "$p"
}

if ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then
  :
elif [[ -x "$ASKPASS" && -f "$TOKEN_FILE" ]]; then
  export GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0
fi

git_fetch() {
  if [[ -n "${GIT_ASKPASS:-}" ]]; then
    git -c credential.helper= fetch --quiet origin
  else
    git fetch --quiet origin
  fi
}

results='[]'
attention=0
fixed=0
TMPDIR_MON="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/hub-repo-mon-$$"
mkdir -p "$TMPDIR_MON"
trap 'rm -rf "$TMPDIR_MON"' EXIT

count="$(jq '.repos | length' "$CONFIG")"
for i in $(seq 0 $((count - 1))); do
  name="$(jq -r ".repos[$i].name" "$CONFIG")"
  org="$(jq -r ".repos[$i].org // \"\"" "$CONFIG")"
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

  status="ok"
  detail=""
  branch="?"
  ahead=0
  behind=0

  if [[ "$org" == "hub" || "$path" == "$ROOT" ]]; then
    if [[ ! -d "$path/.git" ]]; then
      path="$ROOT"
    fi
  fi

  if [[ ! -d "$path/.git" ]]; then
    status="missing"
    detail="not cloned (run scripts/clone-repos.sh)"
    attention=1
    if [[ "$FIX" -eq 1 ]]; then
      if bash "${ROOT}/scripts/clone-repos.sh" "$name" >"$TMPDIR_MON/clone-$name.log" 2>&1; then
        status="cloned"
        detail="cloned via clone-repos.sh"
        fixed=$((fixed + 1))
        attention=0
        path="$(expand "$(jq -r ".repos[$i].path" "$CONFIG")")"
      else
        detail="clone failed"
        attention=1
      fi
    fi
  fi

  if [[ -d "$path/.git" && "$status" != "missing" ]]; then
    gi_state="$(bash "${ROOT}/scripts/ensure-graphify-gitignore.sh" "$path" 2>/dev/null || echo skip)"

    (
      cd "$path"
      branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
      dirty="$(git status --porcelain | grep -vE '^\?\? graphify-out(/|$)' || true)"
      if [[ -n "$dirty" ]]; then
        echo "DIRTY"
        exit 0
      fi
      git_fetch || { echo "FETCH_FAIL"; exit 0; }
      if [[ "$branch" == "HEAD" ]]; then
        echo "DETACHED"
        exit 0
      fi
      upstream="origin/${branch}"
      if ! git rev-parse --verify "$upstream" >/dev/null 2>&1; then
        echo "NO_UPSTREAM"
        exit 0
      fi
      la="$(git rev-list --count "${upstream}..HEAD")"
      ra="$(git rev-list --count "HEAD..${upstream}")"
      if [[ "$la" -gt 0 && "$ra" -gt 0 ]]; then
        echo "DIVERGED $la $ra"
        exit 0
      fi
      if [[ "$ra" -gt 0 ]]; then
        if [[ "$FIX" -eq 1 ]]; then
          if git merge --ff-only "$upstream" >/dev/null 2>&1; then
            echo "PULLED $ra"
            exit 0
          fi
          echo "PULL_FAIL $ra"
          exit 0
        fi
        echo "BEHIND $ra"
        exit 0
      fi
      if [[ "$la" -gt 0 ]]; then
        echo "AHEAD $la"
        exit 0
      fi
      echo "OK"
    ) >"$TMPDIR_MON/$name.txt" 2>"$TMPDIR_MON/$name.err" || true

    line="$(cat "$TMPDIR_MON/$name.txt" 2>/dev/null || echo ERR)"
    branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
    case "$line" in
      OK)
        status="ok"
        detail="up to date"
        ;;
      PULLED*)
        behind="${line#PULLED }"
        status="pulled"
        detail="ff-only +${behind}"
        fixed=$((fixed + 1))
        ;;
      BEHIND*)
        behind="${line#BEHIND }"
        status="behind"
        detail="behind origin by ${behind}"
        attention=1
        ;;
      AHEAD*)
        ahead="${line#AHEAD }"
        status="ahead"
        detail="local ahead by ${ahead} — unfinished ship-work?"
        attention=1
        ;;
      DIVERGED*)
        read -r _ da db <<<"$line" || true
        ahead="${da:-0}"
        behind="${db:-0}"
        status="diverged"
        detail="diverged ahead=${ahead} behind=${behind}"
        attention=1
        ;;
      DIRTY)
        status="dirty"
        if [[ "$gi_state" == "updated" ]]; then
          detail="uncommitted changes (graphify-out gitignore touched — ship-work)"
        else
          detail="uncommitted changes"
        fi
        attention=1
        ;;
      DETACHED)
        status="detached"
        detail="detached HEAD"
        attention=1
        ;;
      NO_UPSTREAM)
        status="no_upstream"
        detail="no origin/${branch}"
        attention=1
        ;;
      FETCH_FAIL|PULL_FAIL*|ERR|*)
        status="error"
        detail="${line:-unknown error}"
        attention=1
        ;;
    esac
  fi

  if [[ "$JSON" -eq 1 ]]; then
    results="$(jq -c --arg n "$name" --arg p "$path" --arg s "$status" --arg d "$detail" --arg b "$branch" \
      --argjson a "$ahead" --argjson be "$behind" \
      '. + [{name:$n, path:$p, status:$s, detail:$d, branch:$b, ahead:$a, behind:$be}]' <<<"$results")"
  else
    printf '%-22s %-10s %s\n' "$name" "$status" "$detail"
  fi
done

if [[ "$JSON" -eq 1 ]]; then
  jq -n --argjson repos "$results" --argjson attention "$attention" --argjson fixed "$fixed" \
    '{attention: ($attention != 0), fixed: $fixed, repos: $repos}'
else
  echo "---"
  echo "fixed=$fixed attention=$attention"
fi

[[ "$attention" -eq 0 ]]
