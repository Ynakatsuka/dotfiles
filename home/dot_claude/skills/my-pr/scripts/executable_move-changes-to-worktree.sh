#!/usr/bin/env bash
set -euo pipefail

branch=${1:?Usage: move-changes-to-worktree.sh <new-branch> [worktree-dir]}

case "$branch" in
  main | master | staging | production | develop | release/*)
    echo "ERROR: refusing to create protected branch for PR worktree: $branch" >&2
    exit 1
    ;;
esac

orig_repo=$(git rev-parse --show-toplevel)
cd "$orig_repo"

sanitized_branch=${branch//\//-}
worktree_dir=${2:-"${orig_repo}-worktree/${sanitized_branch}"}

if [[ -e "$worktree_dir" ]]; then
  echo "ERROR: worktree path already exists: $worktree_dir" >&2
  exit 1
fi

tmp_dir=$(mktemp -d)
worktree_created=false
transfer_complete=false

cleanup() {
  status=$?
  rm -rf "$tmp_dir"
  if ((status != 0)) && [[ "$worktree_created" == true && "$transfer_complete" == false ]]; then
    echo "ERROR: removing incomplete worktree: $worktree_dir" >&2
    if ! git worktree remove --force "$worktree_dir" >&2; then
      echo "ERROR: failed to remove incomplete worktree: $worktree_dir" >&2
    fi
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      if ! git branch -D "$branch" >&2; then
        echo "ERROR: failed to remove incomplete branch: $branch" >&2
      fi
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

staged_patch="$tmp_dir/staged.patch"
unstaged_patch="$tmp_dir/unstaged.patch"
untracked_list="$tmp_dir/untracked-files.txt"
intent_to_add_list="$tmp_dir/intent-to-add-files.txt"
pathspec_list="$tmp_dir/pathspecs.txt"

: >"$pathspec_list"
if [[ -n "${MY_PR_PATHSPEC_FILE:-}" ]]; then
  cat "$MY_PR_PATHSPEC_FILE" >"$pathspec_list"
elif [[ -n "${MY_PR_PATHS:-}" ]]; then
  # shellcheck disable=SC2086
  printf '%s\n' $MY_PR_PATHS >"$pathspec_list"
fi
pathspecs=()
while IFS= read -r pathspec || [[ -n "$pathspec" ]]; do
  [[ -n "$pathspec" ]] && pathspecs+=("$pathspec")
done <"$pathspec_list"

if ((${#pathspecs[@]})); then
  git diff --cached --binary -- "${pathspecs[@]}" >"$staged_patch"
  git diff --binary -- "${pathspecs[@]}" >"$unstaged_patch"
  git diff --name-only --diff-filter=A -- "${pathspecs[@]}" >"$intent_to_add_list"
else
  # Bash 3.2 treats an empty array expansion as an unbound variable under
  # `set -u`, so do not pass an optional array to git in this branch.
  git diff --cached --binary >"$staged_patch"
  git diff --binary >"$unstaged_patch"
  git diff --name-only --diff-filter=A >"$intent_to_add_list"
fi

: >"$untracked_list"
if [[ -n "${MY_PR_UNTRACKED_FILE_LIST:-}" ]]; then
  cat "$MY_PR_UNTRACKED_FILE_LIST" >"$untracked_list"
elif [[ -n "${TASK_CREATED_UNTRACKED_FILES:-}" ]]; then
  # shellcheck disable=SC2086
  printf '%s\n' $TASK_CREATED_UNTRACKED_FILES >"$untracked_list"
fi

validate_untracked_path() {
  local file_path=$1
  case "$file_path" in
    /* | ../* | */../* | .)
      echo "ERROR: unsafe untracked path: $file_path" >&2
      exit 1
      ;;
  esac
  if [[ -L "$orig_repo/$file_path" ]]; then
    echo "ERROR: refusing to copy untracked symlink: $file_path" >&2
    exit 1
  fi
  if [[ ! -f "$orig_repo/$file_path" ]]; then
    echo "ERROR: listed untracked file does not exist: $file_path" >&2
    exit 1
  fi
}

while IFS= read -r file_path; do
  [[ -z "$file_path" ]] && continue
  validate_untracked_path "$file_path"
done <"$untracked_list"

git worktree add "$worktree_dir" -b "$branch" HEAD
worktree_created=true

if [[ -s "$staged_patch" ]]; then
  git -C "$worktree_dir" apply --index "$staged_patch"
fi

if [[ -s "$unstaged_patch" ]]; then
  git -C "$worktree_dir" apply "$unstaged_patch"
fi

if [[ -s "$intent_to_add_list" ]]; then
  intent_to_add_files=()
  while IFS= read -r file_path || [[ -n "$file_path" ]]; do
    [[ -n "$file_path" ]] && intent_to_add_files+=("$file_path")
  done <"$intent_to_add_list"
  git -C "$worktree_dir" add -N -- "${intent_to_add_files[@]}"
fi

while IFS= read -r file_path; do
  [[ -z "$file_path" ]] && continue
  mkdir -p "$worktree_dir/$(dirname "$file_path")"
  command cp -pf "$orig_repo/$file_path" "$worktree_dir/$file_path"
  cmp "$orig_repo/$file_path" "$worktree_dir/$file_path" >/dev/null
done <"$untracked_list"

if ((${#pathspecs[@]})); then
  git -C "$worktree_dir" diff --cached --binary -- "${pathspecs[@]}" >"$tmp_dir/worktree-staged.patch"
  git -C "$worktree_dir" diff --binary -- "${pathspecs[@]}" >"$tmp_dir/worktree-unstaged.patch"
else
  git -C "$worktree_dir" diff --cached --binary >"$tmp_dir/worktree-staged.patch"
  git -C "$worktree_dir" diff --binary >"$tmp_dir/worktree-unstaged.patch"
fi

cmp "$staged_patch" "$tmp_dir/worktree-staged.patch" >/dev/null
cmp "$unstaged_patch" "$tmp_dir/worktree-unstaged.patch" >/dev/null
transfer_complete=true

printf 'ORIG_REPO=%s\n' "$orig_repo"
printf 'WORKTREE_DIR=%s\n' "$worktree_dir"
printf 'BRANCH=%s\n' "$branch"
if ((${#pathspecs[@]} > 0)); then
  printf 'Pathspec-limited transfer:\n'
  printf -- '- %s\n' "${pathspecs[@]}"
fi
printf 'Copied tracked changes and explicitly listed untracked files.\n'
printf 'Original repository was not cleaned. Clean it only after reviewing this worktree.\n'
