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

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

if confirm "Clone prezto?"; then
  run git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
fi

if confirm "Clone tmux plugin manager (tpm)?"; then
  run git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

if confirm "Install chezmoi and apply this dotfiles repo?"; then
  run bash -lc 'sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"'
  run bash -lc '"$HOME/.local/bin/chezmoi" init --apply git@github.com:Ynakatsuka/dotfiles.git'
  run bash -lc 'source "$HOME/.zshrc" || true'
fi

if confirm "Change login shell to zsh?"; then
  run chsh -s "$(which zsh)"
fi

log "Dotfiles module completed"

