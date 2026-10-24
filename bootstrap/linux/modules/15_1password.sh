#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../../.." &>/dev/null && pwd)
# shellcheck source=../../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) enable_dry_run ;;
    *)
      warn "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

require_ubuntu
require_cmd dpkg
require_cmd dpkg-query
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" != amd64 ]; then
  warn "1Password's Debian package requires amd64 (detected: $ARCH)."
  exit 1
fi

if dpkg-query -W -f='${Status}' 1password 2>/dev/null | grep -Fxq 'install ok installed'; then
  log "1Password already installed; use APT to update it"
  exit 0
fi

require_cmd curl
require_cmd apt-get
require_cmd sudo

if [ "$DRY_RUN" -eq 1 ]; then
  PACKAGE_DIR=/tmp/1password-bootstrap.XXXXXX
else
  PACKAGE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/1password-bootstrap.XXXXXX")
  trap 'rm -rf "$PACKAGE_DIR"' EXIT
fi
PACKAGE_FILE="$PACKAGE_DIR/1password.deb"

# The official .deb configures the signing key and APT repository for updates.
# https://support.1password.com/install-linux/#debian-or-ubuntu
log "Installing 1Password from its official Debian package"
run curl -fsSL https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb -o "$PACKAGE_FILE"
# Let APT's unprivileged _apt user read the local package.
run chmod 755 "$PACKAGE_DIR"
run chmod 644 "$PACKAGE_FILE"
run sudo apt-get update
run sudo apt-get install -y "$PACKAGE_FILE"

log "1Password module completed"
