#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)
disk_tree="$repo_root/home/dot_local/bin/executable_disk-tree"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/disk-tree-test.XXXXXX")
cleanup() {
  chmod 700 "$test_dir/root/restricted" 2>/dev/null || true
  rm -rf "$test_dir"
}
trap cleanup EXIT
mkdir -p \
  "$test_dir/bin" \
  "$test_dir/root/keep/child" \
  "$test_dir/root/delete-me" \
  "$test_dir/root/link-a" \
  "$test_dir/root/link-b" \
  "$test_dir/root/large" \
  "$test_dir/root/small" \
  "$test_dir/root/restricted"
printf 'keep\n' >"$test_dir/root/keep/child/file.txt"
printf 'delete\n' >"$test_dir/root/delete-me/file.txt"
dd if=/dev/zero of="$test_dir/root/large/file.bin" bs=1024 count=32 2>/dev/null
dd if=/dev/zero of="$test_dir/root/small/file.bin" bs=1024 count=1 2>/dev/null
dd if=/dev/zero of="$test_dir/root/link-b/file.bin" bs=1024 count=8 2>/dev/null
ln "$test_dir/root/link-b/file.bin" "$test_dir/root/link-a/file.bin"
printf 'secret\n' >"$test_dir/root/restricted/file.txt"
chmod 000 "$test_dir/root/restricted"

if ! permission_output=$($disk_tree --list --depth 1 "$test_dir/root" 2>&1); then
  printf '%s\n' "$permission_output" >&2
  fail 'permission-denied child interrupted the scan'
fi
if printf '%s\n' "$permission_output" | grep -Fq ' restricted'; then
  fail 'permission-denied child was included in the tree'
fi
if $disk_tree --list "$test_dir/root/restricted" >"$test_dir/restricted.out" 2>&1; then
  fail 'permission-denied scan root unexpectedly succeeded'
fi
grep -Fq '容量を取得できません' "$test_dir/restricted.out" ||
  fail 'scan root permission error was not surfaced'

depth_one=$($disk_tree --list --depth 1 --jobs 4 "$test_dir/root")
serial_depth_one=$($disk_tree --list --depth 1 --jobs 1 "$test_dir/root")
[ "$depth_one" = "$serial_depth_one" ] || fail 'parallel scan changed the tree output'
printf '%s\n' "$depth_one" | grep -Fq ' keep' || fail 'depth 1 omitted a direct child'
printf '%s\n' "$depth_one" | grep -Fq ' delete-me' || fail 'depth 1 omitted a direct child'
if printf '%s\n' "$depth_one" | grep -Fq ' child'; then
  fail 'depth 1 included a grandchild'
fi
large_line=$(printf '%s\n' "$depth_one" | grep -n ' large$' | cut -d: -f1)
small_line=$(printf '%s\n' "$depth_one" | grep -n ' small$' | cut -d: -f1)
[ "$large_line" -lt "$small_line" ] || fail 'directories were not sorted by size descending'

depth_two=$($disk_tree --list --depth 2 "$test_dir/root")
printf '%s\n' "$depth_two" | grep -Fq ' child' || fail 'depth 2 omitted a grandchild'

cat >"$test_dir/bin/fzf" <<'PYTHON'
#!/usr/bin/env python3
import os
import sys
from pathlib import Path

rows = [row for row in sys.stdin.buffer.read().split(b"\0") if row]
state_path = Path(os.environ["TEST_FZF_STATE"])
count = int(state_path.read_text()) if state_path.exists() else 0
state_path.write_text(str(count + 1))

mode = os.environ["TEST_FZF_MODE"]
if mode == "protect":
    target = next((row for row in rows if row.startswith(b"0\t")), None)
else:
    target_name = "keep" if mode == "expand" else "delete-me"
    target = next(
        (row for row in rows if row.decode(errors="replace").endswith(f" {target_name}")),
        None,
    )

if mode == "expand":
    log_path = Path(f"{os.environ['TEST_FZF_LOG']}.{count}")
    log_path.write_bytes(b"\n".join(rows))
    if count == 0 and target is not None:
        sys.stdout.buffer.write(b"\0alt-right\0" + target + b"\0")
        raise SystemExit(0)
    raise SystemExit(130)

if target is None:
    raise SystemExit(130)
sys.stdout.buffer.write(b"\0ctrl-d\0" + target + b"\0")
PYTHON

cat >"$test_dir/bin/trash" <<'SHELL'
#!/bin/sh
set -eu
printf '%s\n' "$@" > "$TEST_TRASH_LOG"
for target_path do
  mv "$target_path" "$TEST_TRASH_DEST/"
done
SHELL
chmod +x "$test_dir/bin/fzf" "$test_dir/bin/trash"

export PATH="$test_dir/bin:/usr/bin:/bin"
export TEST_FZF_STATE="$test_dir/fzf-state"
export TEST_FZF_LOG="$test_dir/fzf-log"
export TEST_FZF_MODE=expand
if ! $disk_tree --depth 1 "$test_dir/root" >"$test_dir/expand.out" 2>&1; then
  cat "$test_dir/expand.out" >&2
  fail 'interactive expansion failed'
fi
grep -Fq ' child' "$test_dir/fzf-log.1" || fail 'Alt-Right did not reveal the next level'

rm -f "$TEST_FZF_STATE"
mkdir "$test_dir/trash"
delete_path=$(cd -- "$test_dir/root/delete-me" >/dev/null && pwd -P)
export TEST_FZF_MODE=delete
export TEST_TRASH_DEST="$test_dir/trash"
export TEST_TRASH_LOG="$test_dir/trash.log"
if ! printf 'y\n' | $disk_tree --depth 1 "$test_dir/root" >"$test_dir/delete.out" 2>&1; then
  cat "$test_dir/delete.out" >&2
  fail 'interactive deletion failed'
fi
[ ! -d "$test_dir/root/delete-me" ] || fail 'selected directory was not moved'
[ -d "$test_dir/trash/delete-me" ] || fail 'selected directory did not reach Trash stub'
grep -Fxq "$delete_path" "$test_dir/trash.log" || fail 'wrong path was trashed'

rm -f "$TEST_FZF_STATE"
export TEST_FZF_MODE=protect
if $disk_tree --depth 1 "$test_dir/root" >"$test_dir/protect.out" 2>&1; then
  fail 'scan root was accepted for deletion'
fi
grep -Fq '保護対象は削除できません' "$test_dir/protect.out" || fail 'root protection error was not surfaced'

printf '%s\n' 'test-disk-tree: OK'
