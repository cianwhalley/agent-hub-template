#!/usr/bin/env bash
# Extract Graphify per repo (graphify:true) and merge into hub/graphify-out.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT}/config/repos.json"
OUT="${ROOT}/graphify-out"
TMP="${OUT}/.merge-inputs"
mkdir -p "$OUT" "$TMP"
rm -f "$TMP"/*.json 2>/dev/null || true

expand() {
  local p="$1"
  p="${p/#\~/$HOME}"
  echo "$p"
}

run_graphify() {
  local dir="$1"
  if command -v graphify >/dev/null 2>&1; then
    (cd "$dir" && graphify . --code-only)
  else
    (cd "$dir" && python3 -m graphify . --code-only)
  fi
}

count="$(jq '.repos | length' "$CONFIG")"
inputs=()

for i in $(seq 0 $((count - 1))); do
  g="$(jq -r ".repos[$i].graphify // false" "$CONFIG")"
  [[ "$g" == "true" ]] || continue
  name="$(jq -r ".repos[$i].name" "$CONFIG")"
  path="$(expand "$(jq -r ".repos[$i].path" "$CONFIG")")"
  echo "==> graphify $name"
  if [[ ! -d "$path" ]]; then
    echo "  SKIP: missing $path"
    continue
  fi
  run_graphify "$path"
  bash "${ROOT}/scripts/ensure-graphify-gitignore.sh" "$path" >/dev/null || true
  if [[ -f "$path/graphify-out/graph.json" ]]; then
    cp "$path/graphify-out/graph.json" "$TMP/${name}.json"
    inputs+=("$TMP/${name}.json")
  else
    echo "  WARN: no graph.json for $name"
  fi
done

bash "${ROOT}/scripts/ensure-graphify-gitignore.sh" "$ROOT" >/dev/null || true

if [[ ${#inputs[@]} -eq 0 ]]; then
  echo "no graphs to merge" >&2
  exit 1
fi

if [[ ${#inputs[@]} -eq 1 ]]; then
  cp "${inputs[0]}" "$OUT/graph.json"
  echo "wrote $OUT/graph.json (single repo)"
  exit 0
fi

if graphify merge-graphs --help >/dev/null 2>&1; then
  graphify merge-graphs "${inputs[@]}" --out "$OUT/graph.json"
elif python3 -m graphify merge-graphs --help >/dev/null 2>&1; then
  python3 -m graphify merge-graphs "${inputs[@]}" --out "$OUT/graph.json"
else
  cp "${inputs[0]}" "$OUT/graph.json"
  echo "WARN: merge-graphs unavailable; wrote first graph only (${#inputs[@]} available)" >&2
fi

echo "wrote $OUT/graph.json"
