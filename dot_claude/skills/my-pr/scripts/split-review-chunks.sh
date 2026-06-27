#!/usr/bin/env bash
set -euo pipefail

base_branch=${1:?Usage: split-review-chunks.sh <base-branch>}
: "${MY_PR_ARTIFACT_DIR:?Run prepare-review-artifacts.sh first and export MY_PR_ARTIFACT_DIR}"

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

changed_files="$MY_PR_ARTIFACT_DIR/changed-files.txt"
if [[ ! -f "$changed_files" ]]; then
  echo "ERROR: changed files artifact not found: $changed_files" >&2
  exit 1
fi

chunks_dir="$MY_PR_ARTIFACT_DIR/chunks"
mkdir -p "$chunks_dir"

groups_file="$chunks_dir/groups.txt"
awk -F/ 'NF == 1 { print $1; next } { print $1 }' "$changed_files" |
  sort -u >"$groups_file"

chunk_index=0
while IFS= read -r group; do
  [[ -z "$group" ]] && continue
  chunk_index=$((chunk_index + 1))
  safe_group=$(printf '%s' "$group" | tr -c 'A-Za-z0-9._-' '_')
  chunk_dir="$chunks_dir/$(printf '%02d-%s' "$chunk_index" "$safe_group")"
  mkdir -p "$chunk_dir"

  awk -v group="$group" -F/ '
    (NF == 1 && $1 == group) || (NF > 1 && $1 == group) { print }
  ' "$changed_files" >"$chunk_dir/files.txt"
  awk 'NR == FNR { covered[$0] = 1; next } !($0 in covered) { print }' \
    "$chunk_dir/files.txt" "$changed_files" >"$chunk_dir/files-not-covered.txt"

  mapfile -t files <"$chunk_dir/files.txt"
  if (( ${#files[@]} == 0 )); then
    echo "ERROR: empty chunk for group: $group" >&2
    exit 1
  fi

  git diff --binary "$base_branch"...HEAD -- "${files[@]}" >"$chunk_dir/branch.diff"
  git diff --cached --binary -- "${files[@]}" >"$chunk_dir/staged.diff"
  git diff --binary -- "${files[@]}" >"$chunk_dir/unstaged.diff"

  {
    printf 'Chunk id: %02d-%s\n' "$chunk_index" "$safe_group"
    printf 'Group: %s\n' "$group"
    printf 'Files covered:\n'
    sed 's/^/- /' "$chunk_dir/files.txt"
    printf 'Files not covered:\n'
    if [[ -s "$chunk_dir/files-not-covered.txt" ]]; then
      sed 's/^/- /' "$chunk_dir/files-not-covered.txt"
    else
      printf '%s\n' '- (none)'
    fi
    printf '\n# Branch diff\n'
    cat "$chunk_dir/branch.diff"
    printf '\n# Staged diff\n'
    cat "$chunk_dir/staged.diff"
    printf '\n# Unstaged diff\n'
    cat "$chunk_dir/unstaged.diff"
  } >"$chunk_dir/review.diff"

  printf '%s %s %s\n' \
    "$(printf '%02d-%s' "$chunk_index" "$safe_group")" \
    "$(wc -l <"$chunk_dir/review.diff" | tr -d ' ')" \
    "$chunk_dir/review.diff"
done <"$groups_file" >"$chunks_dir/manifest.txt"

printf 'MY_PR_CHUNKS_DIR=%s\n' "$chunks_dir"
printf 'MY_PR_CHUNK_MANIFEST=%s\n' "$chunks_dir/manifest.txt"
