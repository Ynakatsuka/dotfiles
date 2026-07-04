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
require_cmd curl
require_cmd apt-get

log "Configuring Docker APT repository"
run sudo install -m 0755 -d /etc/apt/keyrings
if [ -f /etc/apt/keyrings/docker.gpg ]; then
  log "Docker GPG keyring already present; skipping write"
else
  run bash -c 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
  run sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi
if [ -f /etc/apt/sources.list.d/docker.list ]; then
  log "Docker sources list already present; skipping write"
else
  run bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
fi
run sudo apt-get update -y
run sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if confirm "Add current user to docker group (requires re-login)?"; then
  run sudo gpasswd -a "$USER" docker
  warn "Please re-login to apply group changes."
fi

log "Docker module completed"
