#!/usr/bin/env bash
# Back up or restore the existing chezmoi age identity with 1Password.
set -euo pipefail
umask 077

usage() {
  echo "Usage: bash bootstrap/age-key.sh <backup|restore> [key-file]"
}

if [[ $# -eq 1 && ("$1" == "--help" || "$1" == "-h") ]]; then
  usage
  exit 0
fi
if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 2
fi
operation=$1
case "$operation" in
  backup | restore) ;;
  *)
    usage >&2
    exit 2
    ;;
esac

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
validation_file="$repo_root/home/private_dot_ssh/encrypted_private_config.age"
key_file=${2:-"$HOME/.config/chezmoi/key.txt"}
vault=Personal
title='chezmoi age key'
work_dir=''

fail() {
  echo "age-key: $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$work_dir" ]]; then
    rm -rf -- "$work_dir"
  fi
}
trap cleanup EXIT

for tool in op age jq python3; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required command not found: $tool"
done
[[ -f "$validation_file" ]] || fail "Validation ciphertext not found: $validation_file"

if [[ "$operation" == restore ]]; then
  if [[ -e "$key_file" || -L "$key_file" ]]; then
    fail "Refusing to overwrite an existing key: $key_file"
  fi
  key_dir=$(dirname "$key_file")
  mkdir -p -- "$key_dir"
  # Keep the temporary file on the destination filesystem for atomic linking.
  work_dir=$(mktemp -d "$key_dir/.age-key-restore.XXXXXX")
else
  [[ -f "$key_file" ]] || fail "Age identity not found: $key_file"
  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-age-key.XXXXXX")
fi
downloaded_key="$work_dir/key.txt"

validate_key() {
  local candidate=$1 status
  [[ -f "$candidate" && ! -L "$candidate" ]] || fail "Expected a regular identity file: $candidate"
  if age --decrypt --identity "$candidate" "$validation_file" >/dev/null 2>"$work_dir/age-error"; then
    return 0
  else
    status=$?
    echo "age-key: Identity validation failed for $candidate (age exited $status)" >&2
    sed -E 's/AGE-SECRET-KEY-[A-Za-z0-9-]+/[REDACTED]/g' "$work_dir/age-error" >&2
    exit "$status"
  fi
}

download_key() {
  op document get "$document_id" --vault "$vault" --out-file "$downloaded_key" --file-mode 0600 >/dev/null
  [[ -f "$downloaded_key" && ! -L "$downloaded_key" ]] || fail "1Password did not return a regular identity file"
  chmod 600 "$downloaded_key"
  validate_key "$downloaded_key"
}

if [[ "$operation" == backup ]]; then
  validate_key "$key_file"
fi

find_document() {
  op document list --vault "$vault" --format json |
    jq -er --arg title "$title" '
      if type != "array" then error("Expected a document list") else . end |
      [.[] | select(.title == $title) | .id] |
      if length == 0 then ""
      elif length == 1 and (.[0] | type == "string" and length > 0) then .[0]
      else error("Expected at most one document named chezmoi age key") end
    '
}

document_id=$(find_document)

if [[ "$operation" == backup ]]; then
  if [[ -z "$document_id" ]]; then
    op document create "$key_file" --vault "$vault" --title "$title" --file-name key.txt --format json >/dev/null
    document_id=$(find_document)
    [[ -n "$document_id" ]] || fail "Document creation succeeded, but the saved document could not be located"
    echo "age-key: Saved identity to 1Password ($vault / $title)"
  fi
  download_key
  cmp -s "$key_file" "$downloaded_key" || fail "The 1Password document differs from the local identity; nothing was overwritten"
  echo "age-key: Backup matches the local identity and decrypts the repository ciphertext"
else
  [[ -n "$document_id" ]] || fail "Document not found in 1Password: $vault / $title"
  download_key
  # link(2) refuses an existing destination, including one created during download.
  python3 - "$downloaded_key" "$key_file" <<'PY'
import os
import sys

os.link(sys.argv[1], sys.argv[2])
PY
  echo "age-key: Restored and validated identity at $key_file (mode 600)"
fi
