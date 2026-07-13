#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if (($# > 0)); then
  move_script=$1
else
  move_script="$repo_root/home/dot_claude/skills/my-pr/scripts/executable_move-changes-to-worktree.sh"
fi
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/my-pr-worktree-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

init_repo() {
  local test_repo=$1

  git init -q "$test_repo"
  git -C "$test_repo" config user.name "my-pr test"
  git -C "$test_repo" config user.email "my-pr@example.invalid"
  printf 'base one\n' >"$test_repo/one.txt"
  printf 'base two\n' >"$test_repo/two.txt"
  git -C "$test_repo" add one.txt two.txt
  git -C "$test_repo" commit -qm "test: add base files"
}

assert_file_content() {
  local file_path=$1
  local expected=$2
  local actual

  actual=$(cat "$file_path")
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: unexpected content in %s\nexpected: %s\nactual: %s\n' \
      "$file_path" "$expected" "$actual" >&2
    exit 1
  fi
}

test_without_pathspecs() {
  local test_repo="$tmp_dir/no-pathspec"
  local worktree_dir="$tmp_dir/no-pathspec-worktree"

  init_repo "$test_repo"
  printf 'staged one\n' >"$test_repo/one.txt"
  git -C "$test_repo" add one.txt
  printf 'unstaged two\n' >"$test_repo/two.txt"

  (
    cd "$test_repo"
    /bin/bash "$move_script" test/no-pathspec "$worktree_dir"
  )

  assert_file_content "$worktree_dir/one.txt" "staged one"
  assert_file_content "$worktree_dir/two.txt" "unstaged two"
  assert_file_content "$test_repo/one.txt" "staged one"
  assert_file_content "$test_repo/two.txt" "unstaged two"
  if git -C "$worktree_dir" diff --cached --quiet -- one.txt; then
    echo "FAIL: staged change was not transferred" >&2
    exit 1
  fi
  if git -C "$worktree_dir" diff --quiet -- two.txt; then
    echo "FAIL: unstaged change was not transferred" >&2
    exit 1
  fi
}

test_with_pathspec_file() {
  local test_repo="$tmp_dir/pathspec"
  local worktree_dir="$tmp_dir/pathspec-worktree"
  local pathspec_file="$tmp_dir/pathspecs.txt"

  init_repo "$test_repo"
  printf 'selected change\n' >"$test_repo/one.txt"
  printf 'unrelated change\n' >"$test_repo/two.txt"
  printf 'one.txt\n' >"$pathspec_file"

  (
    cd "$test_repo"
    MY_PR_PATHSPEC_FILE="$pathspec_file" \
      /bin/bash "$move_script" test/pathspec "$worktree_dir"
  )

  assert_file_content "$worktree_dir/one.txt" "selected change"
  assert_file_content "$worktree_dir/two.txt" "base two"
  assert_file_content "$test_repo/two.txt" "unrelated change"
}

test_without_pathspecs
test_with_pathspec_file

echo "test-my-pr-worktree-move: OK"
