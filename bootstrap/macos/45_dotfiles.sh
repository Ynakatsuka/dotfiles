#!/usr/bin/env bash
set -euo pipefail

# Ensure brew is available in PATH
if ! command -v brew >/dev/null 2>&1; then
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "[ERROR] Homebrew not found. Please install Homebrew first." >&2
    exit 1
  fi
fi

echo "[INFO] Dotfiles setup (prezto/tpm/chezmoi/mise)"

if ! command -v git >/dev/null 2>&1; then
  echo "[ERROR] git is required. Install via Homebrew first." >&2
  exit 1
fi

# Ensure prezto
if [ ! -d "${ZDOTDIR:-$HOME}/.zprezto" ]; then
  read -r -p "Clone prezto? [y/N]: " ans
  if [[ "$ans" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
  else
    echo "[WARN] Skipped prezto clone"
  fi
else
  echo "[INFO] prezto already exists"
fi

# Ensure tmux plugin manager
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  read -r -p "Clone tmux plugin manager (tpm)? [y/N]: " ans
  if [[ "$ans" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  else
    echo "[WARN] Skipped tpm clone"
  fi
else
  echo "[INFO] tpm already exists"
fi

# Ensure chezmoi via Homebrew
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "[INFO] Installing chezmoi via Homebrew"
  brew install chezmoi
fi

# Choose remote protocol for chezmoi init
echo "[INFO] Prepare to initialize chezmoi source"
echo "[INFO] 1) SSH (git@github.com:...) requires working SSH auth"
echo "[INFO] 2) HTTPS (https://github.com/...) works without SSH"
read -r -p "Use SSH for chezmoi init? [y/N]: " use_ssh

source_dir="$HOME/ghq/github.com/Ynakatsuka/dotfiles"
remote_https="https://github.com/Ynakatsuka/dotfiles.git"
remote_ssh="git@github.com:Ynakatsuka/dotfiles.git"

if [[ "$use_ssh" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  remote="$remote_ssh"
else
  remote="$remote_https"
fi

read -r -p "Run 'chezmoi -S $source_dir init --apply' from $remote ? [y/N]: " run_apply
if [[ "$run_apply" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  mkdir -p "$(dirname "$source_dir")"
  chezmoi -S "$source_dir" init --apply "$remote"
else
  echo "[WARN] Skipped chezmoi init/apply"
fi

# Optional: change login shell to zsh (macOS default is zsh, keep optional)
if [ "$(dscl . -read /Users/"$USER" UserShell 2>/dev/null | awk '{print $2}')" != "$(which zsh)" ]; then
  read -r -p "Change your login shell to zsh? [y/N]: " change_shell
  if [[ "$change_shell" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    chsh -s "$(which zsh)"
  else
    echo "[INFO] Keeping current login shell"
  fi
fi

# Optionally run mise up if installed
if command -v mise >/dev/null 2>&1; then
  read -r -p "Run 'mise up' to install dev tools? [y/N]: " run_mise
  if [[ "$run_mise" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    mise up || true
  fi
else
  echo "[WARN] mise not found. Install via Homebrew (brew install mise) if needed."
fi

# Install Claude Code (native installer)
if ! command -v claude >/dev/null 2>&1; then
  read -r -p "Install Claude Code (native installer)? [y/N]: " install_claude
  if [[ "$install_claude" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    _install_script=$(mktemp)
    curl --fail -fsSL https://claude.ai/install.sh -o "$_install_script"
    bash "$_install_script"
    rm -f "$_install_script"
  else
    echo "[WARN] Skipped Claude Code installation"
  fi
else
  echo "[INFO] Claude Code already installed"
fi

# Install Antigravity CLI (native installer)
if ! command -v antigravity >/dev/null 2>&1; then
  read -r -p "Install Antigravity CLI (native installer)? [y/N]: " install_antigravity
  if [[ "$install_antigravity" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    _install_script=$(mktemp)
    curl --fail -fsSL https://antigravity.google/cli/install.sh -o "$_install_script"
    bash "$_install_script"
    rm -f "$_install_script"
  else
    echo "[WARN] Skipped Antigravity CLI installation"
  fi
else
  echo "[INFO] Antigravity CLI already installed"
fi

# Install Cursor Agent CLI (native installer)
if ! command -v cursor-agent >/dev/null 2>&1; then
  read -r -p "Install Cursor Agent CLI (native installer)? [y/N]: " install_cursor_agent
  if [[ "$install_cursor_agent" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    _install_script=$(mktemp)
    curl --fail -fsSL https://cursor.com/install -o "$_install_script"
    bash "$_install_script"
    rm -f "$_install_script"
  else
    echo "[WARN] Skipped Cursor Agent CLI installation"
  fi
else
  echo "[INFO] Cursor Agent CLI already installed"
fi

echo "[INFO] Dotfiles setup completed"
