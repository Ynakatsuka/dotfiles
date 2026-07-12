#!/usr/bin/env bash
set -euo pipefail

base_ref=${1:?Usage: split-review-chunks.sh <base-ref>}
if (($# > 1)); then
  echo "ERROR: unexpected argument: $2" >&2
  exit 1
fi
: "${MY_PR_ARTIFACT_DIR:?Run prepare-review-artifacts.sh first and export MY_PR_ARTIFACT_DIR}"

max_chunk_bytes=${MY_PR_REVIEW_CHUNK_MAX_BYTES:-196608}
if [[ ! "$max_chunk_bytes" =~ ^[1-9][0-9]*$ ]] || ((max_chunk_bytes <= 8192 || max_chunk_bytes > 196608)); then
  echo "ERROR: MY_PR_REVIEW_CHUNK_MAX_BYTES must be an integer from 8193 through 196608" >&2
  exit 1
fi
payload_limit=$((max_chunk_bytes - 8192))

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

changed_files="$MY_PR_ARTIFACT_DIR/changed-files.txt"
if [[ ! -f "$changed_files" ]]; then
  echo "ERROR: changed files artifact not found: $changed_files" >&2
  exit 1
fi
if [[ ! -s "$changed_files" ]]; then
  echo "ERROR: changed files artifact is empty: $changed_files" >&2
  exit 1
fi

chunks_dir="$MY_PR_ARTIFACT_DIR/chunks"
rm -rf "$chunks_dir"
mkdir -p "$chunks_dir"

chunk_index=0
manifest_file="$chunks_dir/manifest.txt"
: >"$manifest_file"

diff_bytes_for_file() {
  local file=$1
  local branch_bytes staged_bytes unstaged_bytes

  branch_bytes=$(git diff --binary "$base_ref"...HEAD -- "$file" | wc -c | tr -d ' ')
  staged_bytes=$(git diff --cached --binary -- "$file" | wc -c | tr -d ' ')
  unstaged_bytes=$(git diff --binary -- "$file" | wc -c | tr -d ' ')
  printf '%s\n' "$((branch_bytes + staged_bytes + unstaged_bytes))"
}

reviewable_files="$chunks_dir/reviewable-files.txt"
skipped_files="$chunks_dir/skipped-files.txt"
skipped_summary="$chunks_dir/skipped-files-summary.txt"
: >"$reviewable_files"
: >"$skipped_files"
: >"$skipped_summary"

while IFS= read -r file || [[ -n "$file" ]]; do
  [[ -z "$file" ]] && continue
  file_bytes=$(diff_bytes_for_file "$file")
  if ((file_bytes == 0)); then
    echo "ERROR: changed file produced an empty diff: $file" >&2
    exit 1
  fi
  if ((file_bytes > payload_limit)); then
    printf '%s\n' "$file" >>"$skipped_files"
    printf '%s bytes: %s\n' "$file_bytes" "$file" >>"$skipped_summary"
    printf 'WARNING: skipping oversized file diff: file=%s bytes=%s limit=%s\n' \
      "$file" "$file_bytes" "$payload_limit" >&2
    continue
  fi
  printf '%s\n' "$file" >>"$reviewable_files"
done <"$changed_files"

groups_file="$chunks_dir/groups.txt"
awk -F/ 'NF == 1 { print $1; next } { print $1 }' "$reviewable_files" |
  LC_ALL=C sort -u >"$groups_file"

emit_chunk() {
  local group=$1
  local files_file=$2
  local safe_group chunk_id chunk_dir review_bytes
  local files=()
  local file

  while IFS= read -r file || [[ -n "$file" ]]; do
    [[ -n "$file" ]] && files+=("$file")
  done <"$files_file"
  if ((${#files[@]} == 0)); then
    echo "ERROR: attempted to emit an empty chunk for group: $group" >&2
    exit 1
  fi

  chunk_index=$((chunk_index + 1))
  safe_group=$(printf '%s' "$group" | tr -c 'A-Za-z0-9._-' '_')
  chunk_id=$(printf '%02d-%s' "$chunk_index" "$safe_group")
  chunk_dir="$chunks_dir/$chunk_id"
  mkdir -p "$chunk_dir"
  cp "$files_file" "$chunk_dir/files.txt"
  awk 'NR == FNR { covered[$0] = 1; next } !($0 in covered) { print }' \
    "$chunk_dir/files.txt" "$reviewable_files" >"$chunk_dir/files-not-covered.txt"

  git diff --binary "$base_ref"...HEAD -- "${files[@]}" >"$chunk_dir/branch.diff"
  git diff --cached --binary -- "${files[@]}" >"$chunk_dir/staged.diff"
  git diff --binary -- "${files[@]}" >"$chunk_dir/unstaged.diff"

  {
    printf 'Chunk id: %s\n' "$chunk_id"
    printf 'Group: %s\n' "$group"
    printf 'Files covered:\n'
    sed 's/^/- /' "$chunk_dir/files.txt"
    printf 'Files not covered:\n'
    if [[ -s "$chunk_dir/files-not-covered.txt" ]]; then
      sed 's/^/- /' "$chunk_dir/files-not-covered.txt"
    else
      printf '%s\n' '- (none)'
    fi
    printf 'Files skipped because their complete diff exceeds %s bytes:\n' "$payload_limit"
    if [[ -s "$skipped_summary" ]]; then
      sed 's/^/- /' "$skipped_summary"
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

  review_bytes=$(wc -c <"$chunk_dir/review.diff" | tr -d ' ')
  if ((review_bytes > max_chunk_bytes)); then
    echo "ERROR: chunk exceeds byte limit: id=$chunk_id bytes=$review_bytes limit=$max_chunk_bytes" >&2
    exit 1
  fi

  printf '%s %s %s\n' \
    "$chunk_id" \
    "$(wc -l <"$chunk_dir/review.diff" | tr -d ' ')" \
    "$chunk_dir/review.diff" >>"$manifest_file"
}

while IFS= read -r group; do
  [[ -z "$group" ]] && continue
  group_files="$chunks_dir/.group-files"
  current_files="$chunks_dir/.current-files"
  : >"$current_files"
  current_bytes=0

  awk -v group="$group" -F/ '
    (NF == 1 && $1 == group) || (NF > 1 && $1 == group) { print }
  ' "$reviewable_files" >"$group_files"

  while IFS= read -r file || [[ -n "$file" ]]; do
    [[ -z "$file" ]] && continue
    file_bytes=$(diff_bytes_for_file "$file")
    if [[ -s "$current_files" ]] && ((current_bytes + file_bytes > payload_limit)); then
      emit_chunk "$group" "$current_files"
      : >"$current_files"
      current_bytes=0
    fi
    printf '%s\n' "$file" >>"$current_files"
    current_bytes=$((current_bytes + file_bytes))
  done <"$group_files"

  if [[ -s "$current_files" ]]; then
    emit_chunk "$group" "$current_files"
  fi
done <"$groups_file"

rm -f "$chunks_dir/.group-files" "$chunks_dir/.current-files"

: >"$chunks_dir/all-covered.txt"
while read -r chunk_id _ review_path; do
  cat "$(dirname "$review_path")/files.txt" >>"$chunks_dir/all-covered.txt"
done <"$manifest_file"
LC_ALL=C sort -o "$chunks_dir/all-covered.txt" "$chunks_dir/all-covered.txt"
LC_ALL=C sort "$reviewable_files" >"$chunks_dir/expected-covered.txt"
if ! cmp -s "$chunks_dir/expected-covered.txt" "$chunks_dir/all-covered.txt"; then
  echo "ERROR: chunk file coverage does not match reviewable-files.txt" >&2
  exit 1
fi
if [[ -n "$(uniq -d "$chunks_dir/all-covered.txt")" ]]; then
  echo "ERROR: duplicate file coverage detected across chunks" >&2
  exit 1
fi

reviewable_paths=()
while IFS= read -r file || [[ -n "$file" ]]; do
  [[ -n "$file" ]] && reviewable_paths+=("$file")
done <"$reviewable_files"

for diff_kind in branch staged unstaged; do
  expected_diff="$chunks_dir/expected.$diff_kind.diff"
  combined_diff="$chunks_dir/combined.$diff_kind.diff"
  if ((${#reviewable_paths[@]} > 0)); then
    case "$diff_kind" in
      branch) git diff --binary "$base_ref"...HEAD -- "${reviewable_paths[@]}" >"$expected_diff" ;;
      staged) git diff --cached --binary -- "${reviewable_paths[@]}" >"$expected_diff" ;;
      unstaged) git diff --binary -- "${reviewable_paths[@]}" >"$expected_diff" ;;
    esac
  else
    : >"$expected_diff"
  fi
  : >"$combined_diff"
  while read -r chunk_id _ review_path; do
    cat "$(dirname "$review_path")/$diff_kind.diff" >>"$combined_diff"
  done <"$manifest_file"
  if ! cmp -s "$expected_diff" "$combined_diff"; then
    echo "ERROR: chunk content does not reconstruct $diff_kind.diff" >&2
    exit 1
  fi
done

reviewable_review="$chunks_dir/reviewable.diff"
{
  printf '%s\n' '# Branch diff'
  printf '%s\n' "# Range: $base_ref...HEAD"
  cat "$chunks_dir/combined.branch.diff"
  printf '\n%s\n' '# Staged diff'
  cat "$chunks_dir/combined.staged.diff"
  printf '\n%s\n' '# Unstaged diff'
  cat "$chunks_dir/combined.unstaged.diff"
} >"$reviewable_review"

printf 'MY_PR_CHUNKS_DIR=%q\n' "$chunks_dir"
printf 'MY_PR_CHUNK_MANIFEST=%q\n' "$manifest_file"
printf 'MY_PR_REVIEWABLE_DIFF=%q\n' "$reviewable_review"
printf 'MY_PR_SKIPPED_FILES=%q\n' "$skipped_files"
printf 'MY_PR_SKIPPED_FILE_SUMMARY=%q\n' "$skipped_summary"
