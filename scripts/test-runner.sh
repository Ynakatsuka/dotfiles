#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd -P)
runner="$repo_root/scripts/test.sh"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/test-runner.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

list=$(bash "$runner" --list)
grep -Fxq 'test-runner' <<<"$list" || {
  echo 'test-runner: self test is unregistered' >&2
  exit 1
}
grep -Fxq 'my-handoff' <<<"$list" || {
  echo 'test-runner: Node test is unregistered' >&2
  exit 1
}
grep -Fxq 'my-japanese-editor' <<<"$list" || {
  echo 'test-runner: Python test is unregistered' >&2
  exit 1
}

if bash "$runner" missing-test >"$test_dir/unknown.log" 2>&1; then
  echo 'test-runner: unknown test was accepted' >&2
  exit 1
fi
grep -Fq 'unknown test: missing-test' "$test_dir/unknown.log"

mkdir "$test_dir/bin"
ln -s "$(command -v bash)" "$test_dir/bin/bash"
if PATH="$test_dir/bin" /bin/bash "$runner" my-handoff >"$test_dir/missing.log" 2>&1; then
  echo 'test-runner: missing tool was accepted' >&2
  exit 1
fi
grep -Fq 'my-handoff requires missing tool: node' "$test_dir/missing.log"
grep -Fq 'my-handoff requires missing tool: git' "$test_dir/missing.log"
[ ! -e "$test_dir/bin/node" ]

output=$(bash "$runner" test-dotfiles-brew-upgrade)
grep -Fq 'PASS test-dotfiles-brew-upgrade' <<<"$output"
grep -Fq 'test.sh: 1 passed, 0 failed, 0 skipped' <<<"$output"

echo 'test-runner: OK'
