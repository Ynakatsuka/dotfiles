#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
. "${SCRIPT_DIR}/../lib/common.sh"

# The minimal plan runs without Homebrew; use it only when present.
activate_brew || true

log "Dotfiles setup (prezto/tpm/chezmoi/mise)"

if ! command -v git >/dev/null 2>&1; then
  warn "git is required. Run 'xcode-select --install' first."
  exit 1
fi

# Ensure prezto
if [ ! -d "${ZDOTDIR:-$HOME}/.zprezto" ]; then
  if confirm "Clone prezto?"; then
    git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
  else
    warn "Skipped prezto clone"
  fi
else
  log "prezto already exists"
fi

# Ensure tmux plugin manager
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  if confirm "Clone tmux plugin manager (tpm)?"; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  else
    warn "Skipped tpm clone"
  fi
else
  log "tpm already exists"
fi

if ! command -v chezmoi >/dev/null 2>&1; then
  log "Installing chezmoi via the official installer"
  install_chezmoi_official -c
  export PATH="$HOME/.local/bin:$PATH"
fi

# Choose remote protocol for chezmoi init
log "Prepare to initialize chezmoi source"
log "1) SSH (git@github.com:...) requires working SSH auth"
log "2) HTTPS (https://github.com/...) works without SSH"
read -r -p "Use SSH for chezmoi init? [y/N]: " use_ssh

source_dir="$HOME/ghq/github.com/Ynakatsuka/dotfiles"
remote_https="https://github.com/Ynakatsuka/dotfiles.git"
remote_ssh="git@github.com:Ynakatsuka/dotfiles.git"

if [[ "$use_ssh" =~ ^[yY]$ ]]; then
  remote="$remote_ssh"
else
  remote="$remote_https"
fi

if confirm "Run 'chezmoi -S $source_dir init --apply' from $remote ?"; then
  mkdir -p "$(dirname "$source_dir")"
  chezmoi -S "$source_dir" init --apply "$remote"
else
  warn "Skipped chezmoi init/apply"
fi

# Optional: change login shell to zsh (macOS default is zsh, keep optional)
if [ "$(dscl . -read /Users/"$USER" UserShell 2>/dev/null | awk '{print $2}')" != "$(command -v zsh)" ]; then
  if confirm "Change your login shell to zsh?"; then
    chsh -s "$(command -v zsh)"
  else
    log "Keeping current login shell"
  fi
fi

# Install agent CLIs via their vendor install scripts
install_cli_via_script claude "Claude Code" https://claude.ai/install.sh
install_cli_via_script agy "Antigravity CLI" https://antigravity.google/cli/install.sh

log "Dotfiles setup completed"
