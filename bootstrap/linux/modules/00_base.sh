#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../../.." &>/dev/null && pwd)
# shellcheck source=../../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

DRY_RUN=0
XDG_ENGLISH_DIRS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --xdg-english-dirs) XDG_ENGLISH_DIRS=1 ;;
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

log "Updating apt and installing base packages"
run sudo apt-get update -y
run sudo apt-get upgrade -y
run sudo apt-get install -y openssh-server curl wget git vim htop zsh tmux ca-certificates gnupg

log "Checking sshd status"
if command -v systemctl >/dev/null 2>&1; then
  run sudo systemctl status sshd.service || true
else
  warn "systemctl not found; skipping sshd status check"
fi

log "Locale configuration"
if confirm "Set locale to en_US.UTF-8?"; then
  run sudo localectl set-locale LANG=en_US.UTF-8 || true
  run sudo update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en || true
else
  warn "Skipped locale change"
fi

if [ "$XDG_ENGLISH_DIRS" -eq 1 ]; then
  if confirm "Convert XDG user dirs to English names and update?"; then
    run mkdir -p "$HOME/.config"
    run sed -i.bak \
      -e 's#XDG_DESKTOP_DIR=.*#XDG_DESKTOP_DIR="$HOME/Desktop"#' \
      -e 's#XDG_DOWNLOAD_DIR=.*#XDG_DOWNLOAD_DIR="$HOME/Downloads"#' \
      -e 's#XDG_TEMPLATES_DIR=.*#XDG_TEMPLATES_DIR="$HOME/Templates"#' \
      -e 's#XDG_PUBLICSHARE_DIR=.*#XDG_PUBLICSHARE_DIR="$HOME/Public"#' \
      -e 's#XDG_DOCUMENTS_DIR=.*#XDG_DOCUMENTS_DIR="$HOME/Documents"#' \
      -e 's#XDG_MUSIC_DIR=.*#XDG_MUSIC_DIR="$HOME/Music"#' \
      -e 's#XDG_PICTURES_DIR=.*#XDG_PICTURES_DIR="$HOME/Pictures"#' \
      -e 's#XDG_VIDEOS_DIR=.*#XDG_VIDEOS_DIR="$HOME/Videos"#' \
      "$HOME/.config/user-dirs.dirs" || true

    for p in Downloads Desktop Templates Public Documents Pictures Videos Music; do
      if [ -d "$HOME/$p" ]; then
        log "Keeping $p"
      fi
    done
    run xdg-user-dirs-update || true

    if confirm "Remove Japanese-named default directories (Documents/Music/etc.)?"; then
      run rm -rf "$HOME/Documents" "$HOME/Music" "$HOME/Pictures" "$HOME/Public" "$HOME/Templates" "$HOME/Videos" || true
    else
      warn "Skipped removing default directories"
    fi
  else
    warn "Skipped XDG conversion"
  fi
fi

log "Base module completed"

