#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../../.." &>/dev/null && pwd)
# shellcheck source=../../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    *) warn "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

require_ubuntu
require_cmd apt-get

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

if confirm "Install GitHub CLI (gh)?"; then
  run sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key 23F3D4EA75716059 || true
  run sudo apt-add-repository https://cli.github.com/packages || true
  run sudo apt update -y
  run sudo apt install -y gh
  warn "Run 'gh auth login' manually after installation."
fi

if confirm "Install uv (via installer script)?"; then
  run bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  run bash -lc 'source "$HOME/.cargo/env" || true'
  run bash -lc 'uvx ruff || true'
  run bash -lc 'uvx mypy || true'
  run bash -lc 'uvx sqlfluff || true'
fi

if confirm "Install rye (optional)?"; then
  run bash -lc 'curl -sSf https://rye.astral.sh/get | bash'
  run bash -lc 'echo '"'"'source "$HOME/.rye/env"'"'"' >> "$HOME/.zshrc"'
fi

if confirm "Install direnv?"; then
  run bash -lc 'curl -sfL https://direnv.net/install.sh | bash'
fi

if confirm "Install Google Cloud CLI?"; then
  run sudo apt-get install -y apt-transport-https ca-certificates gnupg curl sudo
  run bash -lc 'curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -'
  run bash -lc 'echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list'
  run bash -lc 'curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -'
  run sudo apt-get update -y
  run sudo apt-get install -y google-cloud-cli
fi

if confirm "Install Tailscale? (login needs manual 'tailscale up')"; then
  run bash -lc 'curl -fsSL https://tailscale.com/install.sh | sh'
  warn "Run 'sudo tailscale up' manually after installation."
fi

log "CLIs module completed"

