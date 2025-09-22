#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../../.." &>/dev/null && pwd)
# shellcheck source=../../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

DRY_RUN=0
VERSION="3.69.0.0-1"
PKG="expressvpn_${VERSION}_amd64.deb"
URL="https://www.expressvpn.works/clients/linux/${PKG}"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    *) warn "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

require_ubuntu
require_cmd wget

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

if confirm "Download and install ExpressVPN ${VERSION}?"; then
  run wget -O "$PKG" "$URL"
  run sudo dpkg -i "$PKG" || true
  warn "ExpressVPN often requires interactive login; follow vendor guidance."
else
  warn "Skipped ExpressVPN installation"
fi

log "ExpressVPN module completed"

