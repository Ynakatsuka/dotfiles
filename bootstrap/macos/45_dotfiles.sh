#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
. "${SCRIPT_DIR}/../lib/common.sh"

# Ensure brew is available in PATH
if ! command -v brew >/dev/null 2>&1; then
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    warn "Homebrew not found. Please install Homebrew first."
    exit 1
  fi
fi

log "Dotfiles setup (prezto/tpm/chezmoi/mise)"

if ! command -v git >/dev/null 2>&1; then
  warn "git is required. Install via Homebrew first."
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

# Ensure chezmoi via Homebrew
if ! command -v chezmoi >/dev/null 2>&1; then
  log "Installing chezmoi via Homebrew"
  brew install chezmoi
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
if [ "$(dscl . -read /Users/"$USER" UserShell 2>/dev/null | awk '{print $2}')" != "$(which zsh)" ]; then
  if confirm "Change your login shell to zsh?"; then
    chsh -s "$(which zsh)"
  else
    log "Keeping current login shell"
  fi
fi

# Install Claude Code (native installer)
if ! command -v claude >/dev/null 2>&1; then
  if confirm "Install Claude Code (native installer)?"; then
    _install_script=$(mktemp)
    curl --fail -fsSL https://claude.ai/install.sh -o "$_install_script"
    bash "$_install_script"
    rm -f "$_install_script"
  else
    warn "Skipped Claude Code installation"
  fi
else
  log "Claude Code already installed"
fi

# Install Antigravity CLI (native installer)
if ! command -v antigravity >/dev/null 2>&1; then
  if confirm "Install Antigravity CLI (native installer)?"; then
    _install_script=$(mktemp)
    curl --fail -fsSL https://antigravity.google/cli/install.sh -o "$_install_script"
    bash "$_install_script"
    rm -f "$_install_script"
  else
    warn "Skipped Antigravity CLI installation"
  fi
else
  log "Antigravity CLI already installed"
fi

# Install Cursor Agent CLI (native installer)
if ! command -v cursor-agent >/dev/null 2>&1; then
  if confirm "Install Cursor Agent CLI (native installer)?"; then
    _install_script=$(mktemp)
    curl --fail -fsSL https://cursor.com/install -o "$_install_script"
    bash "$_install_script"
    rm -f "$_install_script"
  else
    warn "Skipped Cursor Agent CLI installation"
  fi
else
  log "Cursor Agent CLI already installed"
fi

log "Dotfiles setup completed"
