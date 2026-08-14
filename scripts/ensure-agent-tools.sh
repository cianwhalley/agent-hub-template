#!/usr/bin/env bash
# Install / verify host tools skills need (user-local, no sudo).
# Prefer musl gws on Linux — do NOT use `npm i -g @googleworkspace/cli` on
# Ubuntu 22.04: that gnu binary needs glibc ≥ 2.39 and fails with EACCES.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
mkdir -p "${HOME}/.local/bin" "${HOME}/.local/share" "${HOME}/.config/environment.d"

# systemd user + login shells (Slack units already prepend ~/.local/bin)
ENV_DROPIN="${HOME}/.config/environment.d/99-agent-local-bin.conf"
if [[ ! -f "$ENV_DROPIN" ]] || ! grep -q '\.local/bin' "$ENV_DROPIN" 2>/dev/null; then
  printf 'PATH=%s/.local/bin:/usr/local/bin:/usr/bin:/bin\n' "$HOME" >"$ENV_DROPIN"
fi

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ensure-agent-tools: missing required binary: $1" >&2
    return 1
  }
}

gws_ok() {
  command -v gws >/dev/null 2>&1 || return 1
  gws --version >/dev/null 2>&1
}

install_gws_musl() {
  local ver="${GWS_VERSION:-0.22.5}"
  local arch
  case "$(uname -m)" in
    x86_64 | amd64) arch=x86_64 ;;
    aarch64 | arm64) arch=aarch64 ;;
    *)
      echo "ensure-agent-tools: unsupported arch for gws: $(uname -m)" >&2
      return 1
      ;;
  esac
  local url="https://github.com/googleworkspace/cli/releases/download/v${ver}/google-workspace-cli-${arch}-unknown-linux-musl.tar.gz"
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  curl -fsSL "$url" -o "${tmp}/gws.tgz"
  tar -xzf "${tmp}/gws.tgz" -C "$tmp"
  local bin
  bin="$(find "$tmp" -type f -name gws | head -1)"
  test -n "$bin"
  # Drop broken npm gnu shim if present
  rm -f "${HOME}/.local/bin/gws"
  install -m 0755 "$bin" "${HOME}/.local/bin/gws"
  echo "$ver" >"${HOME}/.local/share/gws-version"
  gws_ok
}

case "$(uname -s)" in
  Linux)
    if ! gws_ok; then
      echo "ensure-agent-tools: installing musl gws into ~/.local/bin"
      install_gws_musl
    fi
    ;;
  Darwin)
    if ! command -v gws >/dev/null 2>&1; then
      echo "ensure-agent-tools: install gws on macOS via: npm i -g @googleworkspace/cli  (or brew)" >&2
    fi
    ;;
esac

# Hard requirements shared by hubs
MISS=0
for bin in node npm jq curl; do
  need "$bin" || MISS=1
done

# gws required when this hub ships google-workspace wrappers
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x "$ROOT/skills/google-workspace/bin/gws-ct" ]] || [[ -x "$ROOT/skills/google-workspace/bin/gws-meridian" ]]; then
  need gws || MISS=1
fi

# Soft (skill-specific) — warn only
for bin in agent-vault graphify gh pandoc sftp; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ensure-agent-tools: optional missing: $bin" >&2
  fi
done

if [[ "$MISS" -ne 0 ]]; then
  echo "ensure-agent-tools: failed" >&2
  exit 1
fi

echo "ensure-agent-tools: ok (gws=$(command -v gws))"
