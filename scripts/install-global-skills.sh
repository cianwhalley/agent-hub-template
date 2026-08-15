#!/usr/bin/env bash
# Install curated Silas global-skills into Cursor (and optionally Claude) personal skills dirs.
# Usage:
#   bash scripts/install-global-skills.sh
#   bash scripts/install-global-skills.sh --also-claude
#   bash scripts/install-global-skills.sh --dest ~/custom/skills
#   bash scripts/install-global-skills.sh --list --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/global-skills"
MANIFEST="$SRC/MANIFEST.json"

ALSO_CLAUDE=0
DRY=0
LIST=0
CUSTOM_DEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --also-claude) ALSO_CLAUDE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --list) LIST=1; shift ;;
    --dest) CUSTOM_DEST="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$MANIFEST" ]]; then
  echo "Missing $MANIFEST" >&2
  exit 1
fi

expand_tilde() {
  local p="$1"
  if [[ "$p" == ~* ]]; then
    echo "${p/#\~/$HOME}"
  else
    echo "$p"
  fi
}

skill_ids=()
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r id; do
    [[ -n "$id" ]] && skill_ids+=("$id")
  done < <(jq -r '.skills[].id' "$MANIFEST")
else
  # Fallback without jq: known required set
  skill_ids=(esignatures secrets)
fi

if [[ "$LIST" -eq 1 ]]; then
  echo "Source: $SRC"
  echo "Skills:"
  for id in "${skill_ids[@]}"; do
    echo "  - $id"
  done
  echo "Default dest: $(expand_tilde "$(jq -r '.installDefault // "~/.cursor/skills"' "$MANIFEST" 2>/dev/null || echo '~/.cursor/skills')")"
  exit 0
fi

dests=()
if [[ -n "$CUSTOM_DEST" ]]; then
  dests+=("$(expand_tilde "$CUSTOM_DEST")")
else
  dests+=("$(expand_tilde ~/.cursor/skills)")
  if [[ "$ALSO_CLAUDE" -eq 1 ]]; then
    dests+=("$(expand_tilde ~/.claude/skills)")
  fi
fi

install_one() {
  local id="$1" dest_root="$2"
  local from="$SRC/$id"
  local to="$dest_root/$id"
  if [[ ! -d "$from" ]]; then
    echo "skip missing source: $from" >&2
    return 1
  fi
  if [[ ! -f "$from/SKILL.md" ]]; then
    echo "skip no SKILL.md: $from" >&2
    return 1
  fi
  echo "→ $to"
  if [[ "$DRY" -eq 1 ]]; then
    return 0
  fi
  mkdir -p "$dest_root"
  rm -rf "$to"
  mkdir -p "$to"
  # Copy skill tree (no node_modules)
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude node_modules --exclude .DS_Store "$from/" "$to/"
  else
    cp -R "$from/." "$to/"
    rm -rf "$to/scripts/node_modules" 2>/dev/null || true
  fi
  if [[ -f "$to/scripts/package.json" ]]; then
    (cd "$to/scripts" && npm install --omit=dev --no-fund --no-audit) || \
      echo "warn: npm install failed in $to/scripts — run manually" >&2
  fi
}

for dest in "${dests[@]}"; do
  echo "Installing Silas global-skills → $dest"
  for id in "${skill_ids[@]}"; do
    install_one "$id" "$dest"
  done
done

# Optional defaults seed (do not overwrite)
if [[ "$DRY" -eq 0 ]]; then
  DEF_DIR="$HOME/.config/claude-skills"
  DEF_FILE="$DEF_DIR/esignatures-defaults.json"
  EXAMPLE="$SRC/esignatures/defaults.example.json"
  if [[ -f "$EXAMPLE" && ! -f "$DEF_FILE" ]]; then
    mkdir -p "$DEF_DIR"
    cp "$EXAMPLE" "$DEF_FILE"
    echo "Seeded $DEF_FILE (edit template UUIDs)"
  fi
fi

echo "Done. Prefer: source scripts/vault-env.sh && bash scripts/esignatures.sh templates list"
