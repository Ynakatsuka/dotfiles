#!/usr/bin/env bash
set -euo pipefail

base_ref=${1:?Usage: prepare-review-artifacts.sh <base-ref>}
if (($# > 1)); then
  echo "ERROR: unexpected argument: $2" >&2
  exit 1
fi
diff_range="$base_ref"...HEAD

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

artifact_parent=${MY_PR_ARTIFACT_PARENT:-.tmp/my-pr}
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
artifact_dir="$artifact_parent/$timestamp-$$"
mkdir -p "$artifact_dir"

# Keep review artifacts out of commits without changing the working tree.
exclude_file=$(git rev-parse --git-path info/exclude)
if [[ -f "$exclude_file" ]] && ! grep -qxF ".tmp/my-pr/" "$exclude_file"; then
  {
    printf '\n'
    printf '# my-pr review artifacts\n'
    printf '.tmp/my-pr/\n'
  } >>"$exclude_file"
fi

git status --short >"$artifact_dir/status.txt"

git diff --stat "$diff_range" >"$artifact_dir/branch.diffstat"
nul_paths_to_lines() {
  perl -0ne '
    chomp;
    die "ERROR: my-pr does not support file names containing newlines\n" if /\n/;
    print "$_\n";
  '
}

git -c core.quotePath=false diff --name-only -z "$diff_range" |
  nul_paths_to_lines >"$artifact_dir/branch.changed-files.txt"
git diff --binary "$diff_range" >"$artifact_dir/branch.diff"

git diff --cached --binary >"$artifact_dir/staged.diff"
git -c core.quotePath=false diff --name-only --cached -z |
  nul_paths_to_lines >"$artifact_dir/staged.changed-files.txt"

git diff --binary >"$artifact_dir/unstaged.diff"
git -c core.quotePath=false diff --name-only -z |
  nul_paths_to_lines >"$artifact_dir/unstaged.changed-files.txt"
git -c core.quotePath=false ls-files --others --exclude-standard -z |
  nul_paths_to_lines >"$artifact_dir/untracked-files.txt"

{
  printf '%s\n' '# Branch diff'
  printf '%s\n' "# Range: $diff_range"
  cat "$artifact_dir/branch.diff"
  printf '\n%s\n' '# Staged diff'
  cat "$artifact_dir/staged.diff"
  printf '\n%s\n' '# Unstaged diff'
  cat "$artifact_dir/unstaged.diff"
} >"$artifact_dir/review.diff"

{
  cat "$artifact_dir/branch.changed-files.txt"
  cat "$artifact_dir/staged.changed-files.txt"
  cat "$artifact_dir/unstaged.changed-files.txt"
} | LC_ALL=C sort -u >"$artifact_dir/changed-files.txt"

file_count=$(wc -l <"$artifact_dir/changed-files.txt" | tr -d ' ')
untracked_count=$(wc -l <"$artifact_dir/untracked-files.txt" | tr -d ' ')
review_lines=$(wc -l <"$artifact_dir/review.diff" | tr -d ' ')
review_bytes=$(wc -c <"$artifact_dir/review.diff" | tr -d ' ')
commit_count=$(git rev-list --count "$base_ref"..HEAD)
scope_gate=ok
if ((file_count > 100 || review_lines > 10000 || commit_count > 20)); then
  scope_gate=large
fi
if ((untracked_count > 0)); then
  if [[ "$scope_gate" == "large" ]]; then
    scope_gate=large+untracked
  else
    scope_gate=untracked
  fi
fi

{
  printf 'Repository: %s\n' "$repo_root"
  printf 'Base ref: %s\n' "$base_ref"
  printf 'Diff range: %s\n' "$diff_range"
  printf 'Artifact dir: %s\n' "$artifact_dir"
  printf 'Changed files: %s\n' "$file_count"
  printf 'Untracked files: %s\n' "$untracked_count"
  printf 'Review diff lines: %s\n' "$review_lines"
  printf 'Review diff bytes: %s\n' "$review_bytes"
  printf 'Commits ahead of base: %s\n' "$commit_count"
  printf 'Scope gate: %s\n' "$scope_gate"
  printf '\n## Branch diff shortstat\n'
  git diff --shortstat "$diff_range"
  printf '\n## Top changed directories\n'
  awk -F/ 'NF == 1 { print $1; next } { print $1 "/" $2 }' "$artifact_dir/changed-files.txt" |
    sort |
    uniq -c |
    sort -rn
  if ((untracked_count > 0)); then
    printf '\n## Untracked files\n'
    cat "$artifact_dir/untracked-files.txt"
  fi
} >"$artifact_dir/scope-summary.txt"

artifact_env="$artifact_dir/artifact.env"
latest_env="$artifact_parent/latest-env.sh"
{
  printf 'export MY_PR_ARTIFACT_DIR=%q\n' "$artifact_dir"
  printf 'export MY_PR_ARTIFACT_ENV=%q\n' "$artifact_env"
  printf 'export MY_PR_BASE_REF=%q\n' "$base_ref"
  printf 'export MY_PR_REVIEW_DIFF=%q\n' "$artifact_dir/review.diff"
  printf 'export MY_PR_REVIEW_BYTES=%q\n' "$review_bytes"
  printf 'export MY_PR_CHANGED_FILES=%q\n' "$artifact_dir/changed-files.txt"
  printf 'export MY_PR_SCOPE_SUMMARY=%q\n' "$artifact_dir/scope-summary.txt"
  printf 'export MY_PR_SCOPE_GATE=%q\n' "$scope_gate"
} >"$artifact_env"
cp "$artifact_env" "$latest_env"

cat "$artifact_env"
printf 'Review artifacts are local-only. Do not stage or commit .tmp/my-pr/.\n' >&2
printf 'To reuse paths later, source %s.\n' "$artifact_env" >&2
