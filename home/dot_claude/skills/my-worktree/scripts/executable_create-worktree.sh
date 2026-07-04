#!/usr/bin/env bash
# Compatibility wrapper for the shared git worktree creation helper.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# This repo-relative path only resolves when this script runs directly from the
# dotfiles source tree. At the deploy target (~/.claude/skills/...), the
# directory layout differs and this fallback never resolves; the PATH lookup
# for gw-create-worktree below is the deployed path.
repo_helper="${script_dir}/../../../../dot_local/bin/executable_gw-create-worktree"

if command -v gw-create-worktree >/dev/null 2>&1; then
  exec gw-create-worktree "$@"
fi

if [[ -x "$repo_helper" ]]; then
  exec "$repo_helper" "$@"
fi

echo "Error: gw-create-worktree not found. Run chezmoi apply or execute from the dotfiles source tree." >&2
exit 1
