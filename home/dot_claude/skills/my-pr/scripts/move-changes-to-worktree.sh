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
mapfile -t pathspecs <"$pathspec_list"

# Only append the `--` separator and pathspecs when at least one pathspec is
# present. An empty array would otherwise leave a bare trailing `--`.
diff_pathspec_args=()
if ((${#pathspecs[@]})); then
  diff_pathspec_args=(-- "${pathspecs[@]}")
fi

git diff --cached --binary "${diff_pathspec_args[@]}" >"$staged_patch"
git diff --binary "${diff_pathspec_args[@]}" >"$unstaged_patch"
git diff --name-only --diff-filter=A "${diff_pathspec_args[@]}" >"$intent_to_add_list"

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
  mapfile -t intent_to_add_files <"$intent_to_add_list"
  git -C "$worktree_dir" add -N -- "${intent_to_add_files[@]}"
fi

while IFS= read -r file_path; do
  [[ -z "$file_path" ]] && continue
  mkdir -p "$worktree_dir/$(dirname "$file_path")"
  command cp -pf "$orig_repo/$file_path" "$worktree_dir/$file_path"
  cmp "$orig_repo/$file_path" "$worktree_dir/$file_path" >/dev/null
done <"$untracked_list"

git -C "$worktree_dir" diff --cached --binary "${diff_pathspec_args[@]}" >"$tmp_dir/worktree-staged.patch"
git -C "$worktree_dir" diff --binary "${diff_pathspec_args[@]}" >"$tmp_dir/worktree-unstaged.patch"

cmp "$staged_patch" "$tmp_dir/worktree-staged.patch" >/dev/null
cmp "$unstaged_patch" "$tmp_dir/worktree-unstaged.patch" >/dev/null
transfer_complete=true

printf 'WORKTREE_DIR=%s\n' "$worktree_dir"
printf 'BRANCH=%s\n' "$branch"
if ((${#pathspecs[@]} > 0)); then
  printf 'Pathspec-limited transfer:\n'
  printf -- '- %s\n' "${pathspecs[@]}"
fi
printf 'Copied tracked changes and explicitly listed untracked files.\n'
printf 'Original repository was not cleaned. Clean it only after reviewing this worktree.\n'
