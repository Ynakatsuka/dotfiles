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

require_cmd apt-get

if confirm "Run 'apt autoremove'?"; then
  run sudo apt autoremove -y
else
  warn "Skipped cleanup"
fi

log "Cleanup module completed"
