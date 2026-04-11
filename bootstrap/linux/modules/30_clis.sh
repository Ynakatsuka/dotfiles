#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../../.." &>/dev/null && pwd)
# shellcheck source=../../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

DRY_RUN=0
SKIP_AGE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-age) SKIP_AGE=1 ;;
    *)
      warn "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

require_ubuntu

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

has_apt() { command -v apt-get >/dev/null 2>&1; }

if command -v age >/dev/null 2>&1; then
  log "age already installed, skipping"
elif [ "$SKIP_AGE" -eq 0 ] && has_apt && confirm "Install age (file encryption)?"; then
  run sudo apt-get install -y age
fi

# gh is managed by mise (see dot_mise.toml). gh-dash extension is installed
# from main.sh after `mise install` completes.

if command -v uv >/dev/null 2>&1; then
  log "uv already installed, skipping"
elif confirm "Install uv (via installer script)?"; then
  run bash -lc '_s=$(mktemp) && curl --fail -LsS https://astral.sh/uv/install.sh -o "$_s" && sh "$_s" && rm -f "$_s"'
  run bash -lc 'source "$HOME/.cargo/env" || true'
  run bash -lc 'uvx ruff || true'
  run bash -lc 'uvx mypy || true'
  run bash -lc 'uvx sqlfluff || true'
fi

if command -v mise >/dev/null 2>&1 || [ -x "$HOME/.local/bin/mise" ]; then
  log "mise already installed, skipping"
elif confirm "Install mise (via official installer)?"; then
  run bash -lc '_s=$(mktemp) && curl --fail -sS https://mise.run -o "$_s" && sh "$_s" && rm -f "$_s"'
  warn "Restart your shell or source the activation in your rc to use mise."
fi

# rye, direnv, and gcloud are managed by mise (see dot_mise.toml).

if command -v tailscale >/dev/null 2>&1; then
  log "tailscale already installed, skipping"
elif confirm "Install Tailscale? (login needs manual 'tailscale up')"; then
  run bash -lc '_s=$(mktemp) && curl --fail -fsSL https://tailscale.com/install.sh -o "$_s" && sh "$_s" && rm -f "$_s"'
  warn "Run 'sudo tailscale up' manually after installation."
fi

if command -v claude >/dev/null 2>&1; then
  log "claude already installed, skipping"
elif confirm "Install Claude Code (native installer)?"; then
  run bash -lc '_s=$(mktemp) && curl --fail -fsSL https://claude.ai/install.sh -o "$_s" && bash "$_s" && rm -f "$_s"'
fi

log "CLIs module completed"
