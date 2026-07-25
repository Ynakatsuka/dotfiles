#!/usr/bin/env bash
set -euo pipefail

usage='Usage: fetch-pr-briefing.sh [pr-number-or-url]'
if (($# > 1)); then
  echo "ERROR: $usage" >&2
  exit 1
fi
pr_ref=${1:-}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

artifact_parent=${MY_PR_BRIEFING_PARENT:-.tmp/my-pr-briefing}
case "$artifact_parent" in
  /*) ;;
  *) artifact_parent="$repo_root/$artifact_parent" ;;
esac

# Keep briefing artifacts out of commits without changing the working tree.
exclude_file=$(git rev-parse --git-path info/exclude)
if [[ -f "$exclude_file" ]] && ! grep -qxF ".tmp/my-pr-briefing/" "$exclude_file"; then
  {
    printf '\n'
    printf '# my-pr-briefing artifacts\n'
    printf '.tmp/my-pr-briefing/\n'
  } >>"$exclude_file"
fi

pr_fields='number,title,body,url,state,isDraft,baseRefName,headRefName,author,additions,deletions,changedFiles,files,commits,updatedAt'
metadata_tmp=$(mktemp "${TMPDIR:-/tmp}/my-pr-briefing.XXXXXX.json")
trap 'rm -f "$metadata_tmp"' EXIT

if [[ -n "$pr_ref" ]]; then
  gh pr view "$pr_ref" --json "$pr_fields" >"$metadata_tmp"
else
  gh pr view --json "$pr_fields" >"$metadata_tmp"
fi

pr_number=$(jq -r '.number // empty' "$metadata_tmp")
pr_url=$(jq -r '.url // empty' "$metadata_tmp")
if [[ ! "$pr_number" =~ ^[0-9]+$ || -z "$pr_url" ]]; then
  echo "ERROR: could not resolve the target PR from gh pr view output" >&2
  exit 1
fi

# Resolve the PR's own repository so a cross-repository URL is not re-resolved locally.
pr_repo=$(printf '%s\n' "$pr_url" | sed -nE 's#^https?://[^/]+/([^/]+/[^/]+)/pull/[0-9]+.*$#\1#p')
if [[ -z "$pr_repo" ]]; then
  echo "ERROR: could not parse owner/repo from PR URL: $pr_url" >&2
  exit 1
fi

artifact_dir="$artifact_parent/pr-$pr_number"
mkdir -p "$artifact_dir"
mv "$metadata_tmp" "$artifact_dir/pr.json"
trap - EXIT

# The combined diff matches the GitHub "Files changed" view.
# --patch returns per-commit mailbox output and must not be used here.
gh pr diff "$pr_number" --repo "$pr_repo" >"$artifact_dir/pr.diff"

python3 "$script_dir/pr_briefing.py" index \
  --diff "$artifact_dir/pr.diff" \
  --pr-json "$artifact_dir/pr.json" \
  --out "$artifact_dir/files.json"

{
  printf 'PR: #%s %s\n' "$pr_number" "$(jq -r '.title' "$artifact_dir/pr.json")"
  printf 'Repo: %s\n' "$pr_repo"
  printf 'Artifact dir: %s\n' "$artifact_dir"
  printf 'Metadata: %s\n' "$artifact_dir/pr.json"
  printf 'Diff: %s\n' "$artifact_dir/pr.diff"
  printf 'File index: %s\n' "$artifact_dir/files.json"
} >&2
