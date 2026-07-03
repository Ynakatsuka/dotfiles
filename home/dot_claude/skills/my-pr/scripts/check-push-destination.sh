#!/usr/bin/env bash
set -euo pipefail

current_branch=$(git branch --show-current)
if [[ -z "$current_branch" ]]; then
  echo "ERROR: could not determine current branch" >&2
  exit 1
fi

err_file=$(mktemp)
trap 'rm -f "$err_file"' EXIT

if push_ref=$(git rev-parse --abbrev-ref --symbolic-full-name '@{push}' 2>"$err_file"); then
  push_branch=${push_ref#origin/}
else
  if rg -qi "no upstream|no such branch|no configured push|@\{push\}" "$err_file"; then
    echo "No push destination is configured for $current_branch."
    echo "Use: git push -u origin HEAD:$current_branch"
    exit 0
  fi
  cat "$err_file" >&2
  exit 1
fi

case "$push_branch" in
  main|master|staging|production|develop|release/*)
    if [[ "$push_branch" != "$current_branch" ]]; then
      echo "ERROR: push destination is protected and does not match current branch: $push_ref" >&2
      exit 2
    fi
    ;;
esac

echo "Push destination is safe: $push_ref"
