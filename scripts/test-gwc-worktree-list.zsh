#!/usr/bin/env zsh

set -eu

repo_root=${0:A:h:h}
source "$repo_root/home/private_dot_config/zsh/git-worktree.zsh"

fail() {
    print -u2 -- "FAIL: $*"
    exit 1
}

assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$actual" != "$expected" ]]; then
        print -u2 -- "FAIL: $message"
        print -u2 -- "expected: ${(qqq)expected}"
        print -u2 -- "actual:   ${(qqq)actual}"
        exit 1
    fi
}

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gwc-worktree-list-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/worktrees/current" "$tmp_dir/worktrees/old" "$tmp_dir/worktrees/new"

cat > "$tmp_dir/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${TEST_OS:?}"
EOF

cat > "$tmp_dir/bin/git" <<'EOF'
#!/bin/sh
set -eu

if [ "$1" = "worktree" ] && [ "$2" = "list" ]; then
    printf '%s  abc0000 [old]\n' "$TEST_ROOT/worktrees/old"
    printf '%s  abc1111 [current]\n' "$TEST_ROOT/worktrees/current"
    printf '%s  abc2222 [new]\n' "$TEST_ROOT/worktrees/new"
    exit 0
fi

if [ "$1" = "-C" ] && [ "$3" = "symbolic-ref" ]; then
    case "$2" in
        */new) printf '%s\n' 'feat/new' ;;
        */old) printf '%s\n' 'fix/old' ;;
        *) exit 1 ;;
    esac
    exit 0
fi

exit 64
EOF

cat > "$tmp_dir/bin/stat" <<'EOF'
#!/bin/sh
set -eu

case "$TEST_OS:$1:$2" in
    Darwin:-f:%B|Linux:-c:%W) ;;
    *) exit 64 ;;
esac

case "$3" in
    */current) printf '%s\n' 200 ;;
    */old) printf '%s\n' 100 ;;
    */new)
        if [ "${TEST_UNAVAILABLE_BIRTH_TIME:-0}" = 1 ]; then
            printf '%s\n' 0
        else
            printf '%s\n' 300
        fi
        ;;
    *) exit 1 ;;
esac
EOF

cat > "$tmp_dir/bin/date" <<'EOF'
#!/bin/sh
set -eu

case "$TEST_OS:$1:$2:$3" in
    Darwin:-r:300:+%Y/%m/%d\ %H:%M|Linux:-d:@300:+%Y/%m/%d\ %H:%M)
        printf '%s\n' '2026/07/11 12:30'
        ;;
    Darwin:-r:100:+%Y/%m/%d\ %H:%M|Linux:-d:@100:+%Y/%m/%d\ %H:%M)
        printf '%s\n' '2026/07/09 08:05'
        ;;
    *) exit 64 ;;
esac
EOF

chmod +x "$tmp_dir/bin/"*
export PATH="$tmp_dir/bin:/usr/bin:/bin"
export TEST_ROOT="$tmp_dir"

expected="$tmp_dir/worktrees/new"$'\t''2026/07/11 12:30  abc2222 [new]'$'\n'"$tmp_dir/worktrees/old"$'\t''2026/07/09 08:05  abc0000 [old]'
expected_gw="$tmp_dir/worktrees/new  abc2222 [new]"$'\n'"$tmp_dir/worktrees/current  abc1111 [current]"$'\n'"$tmp_dir/worktrees/old  abc0000 [old]"

for TEST_OS in Darwin Linux; do
    export TEST_OS
    gw_list=$(_gw_worktree_list_newest_first)
    assert_equal "$expected_gw" "$gw_list" "$TEST_OS gw list output should remain unchanged"

    actual=$(_gwc_worktree_list_newest_first "$tmp_dir/worktrees/current")
    assert_equal "$expected" "$actual" "$TEST_OS list should be newest-first, dated, and exclude the current worktree"

    first_path=$(print -r -- "$actual" | awk 'NR == 1 { print $1 }')
    assert_equal "$tmp_dir/worktrees/new" "$first_path" "$TEST_OS list should keep the worktree path in field 1"

    _gwc_collect_selected_worktrees "$actual" || fail "$TEST_OS selection parsing failed"
    assert_equal "$tmp_dir/worktrees/new" "${_GWC_WORKTREE_PATHS[1]}" "$TEST_OS first selected path"
    assert_equal "feat/new" "${_GWC_BRANCH_NAMES[1]}" "$TEST_OS first selected branch"
    assert_equal "$tmp_dir/worktrees/old" "${_GWC_WORKTREE_PATHS[2]}" "$TEST_OS second selected path"
    assert_equal "fix/old" "${_GWC_BRANCH_NAMES[2]}" "$TEST_OS second selected branch"
done

TEST_OS=FreeBSD
export TEST_OS
if _gwc_worktree_list_newest_first "$tmp_dir/worktrees/current" > "$tmp_dir/unsupported.out" 2> "$tmp_dir/unsupported.err"; then
    fail "unsupported OS unexpectedly succeeded"
fi
grep -Fq 'Error: unsupported operating system for worktree creation time: FreeBSD' "$tmp_dir/unsupported.err" ||
    fail "unsupported OS error was not surfaced"

TEST_OS=Darwin
TEST_UNAVAILABLE_BIRTH_TIME=1
export TEST_OS TEST_UNAVAILABLE_BIRTH_TIME
if _gwc_worktree_list_newest_first "$tmp_dir/worktrees/current" > "$tmp_dir/unavailable.out" 2> "$tmp_dir/unavailable.err"; then
    fail "unavailable creation time unexpectedly succeeded"
fi
grep -Fq "Error: creation time is unavailable for worktree: $tmp_dir/worktrees/new" "$tmp_dir/unavailable.err" ||
    fail "unavailable creation time error was not surfaced"

print 'test-gwc-worktree-list: OK'
