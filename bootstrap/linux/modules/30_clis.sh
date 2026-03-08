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
    *) warn "Unknown option: $1"; exit 1 ;;
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

if command -v gh >/dev/null 2>&1; then
  log "gh already installed, skipping"
elif has_apt && confirm "Install GitHub CLI (gh)?"; then
  run sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key 23F3D4EA75716059 || true
  run sudo apt-add-repository https://cli.github.com/packages || true
  run sudo apt update -y
  run sudo apt install -y gh
  warn "Run 'gh auth login' manually after installation."
fi

if command -v gh >/dev/null 2>&1 && gh extension list 2>/dev/null | grep -q dlvhdr/gh-dash; then
  log "gh-dash already installed, skipping"
elif command -v gh >/dev/null 2>&1 && confirm "Install gh-dash (GitHub CLI extension for PR/issue dashboard)?"; then
  run gh extension install dlvhdr/gh-dash
fi

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

if command -v rye >/dev/null 2>&1; then
  log "rye already installed, skipping"
elif confirm "Install rye (optional)?"; then
  run bash -lc '_s=$(mktemp) && curl --fail -sS https://rye.astral.sh/get -o "$_s" && bash "$_s" && rm -f "$_s"'
  run bash -lc 'echo '"'"'source "$HOME/.rye/env"'"'"' >> "$HOME/.zshrc"'
fi

if command -v direnv >/dev/null 2>&1; then
  log "direnv already installed, skipping"
elif confirm "Install direnv?"; then
  run bash -lc '_s=$(mktemp) && curl --fail -sL https://direnv.net/install.sh -o "$_s" && bash "$_s" && rm -f "$_s"'
fi

if command -v gcloud >/dev/null 2>&1; then
  log "gcloud already installed, skipping"
elif has_apt && confirm "Install Google Cloud CLI?"; then
  run sudo apt-get install -y apt-transport-https ca-certificates gnupg curl sudo
  run bash -lc 'curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -'
  run bash -lc 'echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list'
  run bash -lc 'curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -'
  run sudo apt-get update -y
  run sudo apt-get install -y google-cloud-cli
fi

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
