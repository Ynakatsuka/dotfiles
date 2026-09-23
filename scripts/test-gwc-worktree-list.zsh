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
mkdir -p "$tmp_dir/bin" "$tmp_dir/common.git" "$tmp_dir/worktrees/current" "$tmp_dir/worktrees/old" "$tmp_dir/worktrees/new"

cat > "$tmp_dir/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${TEST_OS:?}"
EOF

cat > "$tmp_dir/bin/git" <<'EOF'
#!/bin/sh
set -eu

if [ "$1" = "worktree" ] && [ "$2" = "list" ]; then
    if [ "${3:-}" = "--porcelain" ]; then
        printf 'worktree %s\nHEAD abc0000\nbranch refs/heads/fix/old\nprunable missing gitdir\n\n' "$TEST_ROOT/worktrees/old"
        printf 'worktree %s\nHEAD abc1111\nbranch refs/heads/main\n\n' "$TEST_ROOT/worktrees/current"
        printf 'worktree %s\nHEAD abc2222\nbranch refs/heads/feat/new\n\n' "$TEST_ROOT/worktrees/new"
        if [ "${TEST_DUPLICATE_PATH:-0}" = 1 ]; then
            printf 'worktree %s\nHEAD abc2222\nbranch refs/heads/feat/new\n\n' "$TEST_ROOT/worktrees/new"
        fi
        if [ -n "${TEST_FORGED_LATE_METADATA:-}" ]; then
            printf 'worktree %s\nHEAD abc3333\n' "$TEST_ROOT/common.git"
            if [ "$TEST_FORGED_LATE_METADATA" = bare ]; then
                printf 'bare\n\n'
            else
                printf 'branch refs/heads/forged\n\n'
            fi
        fi
        exit 0
    fi
    exit 64
fi

if [ "$1" = "rev-parse" ] && [ "$2" = "--short" ]; then
    printf '%.7s\n' "$3"
    exit 0
fi

if [ "$1" = "rev-parse" ] && [ "$2" = "--git-common-dir" ]; then
    printf '%s\n' 'common.git'
    exit 0
fi

if [ "$1" = "-C" ] && [ "$3" = "rev-parse" ]; then
    case "$4" in
        --git-common-dir)
            if [ "$2" = "$TEST_ROOT/common.git" ]; then
                printf '%s\n' '.'
            else
                printf '%s\n' '../../common.git'
            fi
            ;;
        --show-toplevel)
            if [ "$2" = "$TEST_ROOT/common.git" ]; then
                printf '%s\n' "$TEST_ROOT/worktrees/current"
            else
                printf '%s\n' "$2"
            fi
            ;;
        --absolute-git-dir) printf '%s\n' "$TEST_ROOT/common.git" ;;
        *) exit 64 ;;
    esac
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
    */common.git) printf '%s\n' 400 ;;
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

cp "$repo_root/home/dot_local/bin/executable_dotfiles-worktree-created-at" \
    "$tmp_dir/bin/dotfiles-worktree-created-at"
chmod +x "$tmp_dir/bin/"*
original_path="$PATH"
export PATH="$tmp_dir/bin:/usr/bin:/bin"
export TEST_ROOT="$tmp_dir"
cd "$tmp_dir"

expected="$tmp_dir/worktrees/new"$'\t''2026/07/11 12:30      abc2222 [feat/new]'$'\n'"$tmp_dir/worktrees/old"$'\t''2026/07/09 08:05      abc0000 [fix/old] prunable'
expected_gw="$tmp_dir/worktrees/new      abc2222 [feat/new]"$'\n'"$tmp_dir/worktrees/current  abc1111 [main]"$'\n'"$tmp_dir/worktrees/old      abc0000 [fix/old] prunable"

for TEST_OS in Darwin Linux; do
    export TEST_OS
    gw_list=$(_gw_worktree_list_newest_first)
    assert_equal "$expected_gw" "$gw_list" "$TEST_OS gw list output should remain unchanged"

    actual=$(_gwc_worktree_list_newest_first "$tmp_dir/worktrees/current")
    assert_equal "$expected" "$actual" "$TEST_OS list should be newest-first, dated, and exclude the current worktree"

    selected_rows=$(printf '%s\n' "$actual" | while IFS=$'\t' read -r worktree_path display; do
        printf '%s\t%s\t%s\n' "$worktree_path" "$worktree_path" "$display"
    done)
    _gwc_collect_selected_worktrees "$selected_rows" || fail "$TEST_OS selection parsing failed"
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

TEST_UNAVAILABLE_BIRTH_TIME=0
TEST_DUPLICATE_PATH=1
export TEST_UNAVAILABLE_BIRTH_TIME TEST_DUPLICATE_PATH
if _gw_worktree_list_newest_first > "$tmp_dir/duplicate.out" 2> "$tmp_dir/duplicate.err"; then
    fail 'duplicate worktree path was accepted'
fi
grep -Fq "Error: duplicate git worktree path: $tmp_dir/worktrees/new" "$tmp_dir/duplicate.err" ||
    fail 'duplicate worktree path did not report an explicit error'

TEST_DUPLICATE_PATH=0
TEST_FORGED_LATE_METADATA=branch
export TEST_DUPLICATE_PATH TEST_FORGED_LATE_METADATA
if _gw_worktree_list_newest_first > "$tmp_dir/forged-metadata.out" 2> "$tmp_dir/forged-metadata.err"; then
    fail 'a later common Git directory record was accepted'
fi
grep -Fq "Error: invalid git worktree path: $tmp_dir/common.git" "$tmp_dir/forged-metadata.err" ||
    fail 'a later common Git directory record did not report a validation error'

TEST_FORGED_LATE_METADATA=bare
export TEST_FORGED_LATE_METADATA
if _gw_worktree_list_newest_first > "$tmp_dir/forged-bare.out" 2> "$tmp_dir/forged-bare.err"; then
    fail 'a later bare record was accepted'
fi
grep -Fq "Error: invalid git worktree path: $tmp_dir/common.git" "$tmp_dir/forged-bare.err" ||
    fail 'a later bare record did not report a validation error'

unset TEST_FORGED_LATE_METADATA

mkdir -p "$tmp_dir/real-bin" "$tmp_dir/real-home"
cat > "$tmp_dir/real-bin/dotfiles-worktree-created-at" <<'EOF'
#!/bin/sh
case "$1" in
    *'feature [with] spaces') printf '%s\n' 300 ;;
    *'other worktree') printf '%s\n' 100 ;;
    *) printf '%s\n' 200 ;;
esac
EOF
cat > "$tmp_dir/real-bin/fzf" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$TEST_FZF_ARGS"
while IFS= read -r line; do
    case "$line" in
        *"$TEST_FZF_SELECT"*) printf '%s\n' "$line"; exit 0 ;;
    esac
done
exit 1
EOF
chmod +x "$tmp_dir/real-bin/"*
export PATH="$tmp_dir/real-bin:$original_path"
export HOME="$tmp_dir/real-home"
export TEST_FZF_ARGS="$tmp_dir/fzf.args"

real_repo="$tmp_dir/repo with spaces"
space_worktree="$tmp_dir/feature [with] spaces"
other_worktree="$tmp_dir/other worktree"
detached_worktree="$tmp_dir/detached worktree"
unicode_worktree="$tmp_dir/日本語 worktree"
git init -q "$real_repo"
git -C "$real_repo" config user.name 'gwc test'
git -C "$real_repo" config user.email 'gwc@example.invalid'
print base > "$real_repo/base.txt"
git -C "$real_repo" add base.txt
git -C "$real_repo" commit -qm 'test: add base file'
git -C "$real_repo" worktree add -q -b feat/space "$space_worktree"
git -C "$real_repo" worktree add -q -b fix/other "$other_worktree"
git -C "$real_repo" worktree lock "$other_worktree" --reason 'test lock'
git -C "$real_repo" worktree add -q --detach "$detached_worktree"
git -C "$real_repo" worktree add -q -b test/unicode "$unicode_worktree"

cd "$real_repo"
export TEST_FZF_SELECT="$space_worktree"
actual_display=$(_gw_worktree_list_newest_first | sort)
# Newer Git quotes non-ASCII paths by default; the chooser displays decoded paths.
expected_display=$(git -c core.quotePath=false worktree list | sort)
assert_equal "$expected_display" "$actual_display" 'porcelain display should match git worktree list'
preview_command=$(_gw_worktree_fzf_preview_command)
escaped_path=${(q)space_worktree}
preview_command="${preview_command//\{1\}/$escaped_path}"
sh -c "$preview_command" > "$tmp_dir/preview.out" || fail 'fzf preview failed for a path with spaces'
grep -Fq -- "Path:     $space_worktree" "$tmp_dir/preview.out" || fail 'fzf preview used the wrong worktree path'

gw > "$tmp_dir/gw.out" || fail 'gw could not select a worktree with spaces'
assert_equal "$space_worktree" "$PWD" 'gw selected the complete path with spaces'
grep -Fqx -- '--with-nth=2..' "$TEST_FZF_ARGS" || fail 'gw exposed its selection key in fzf'

cd "$real_repo"
printf 'y\n' | gwc -j 1 > "$tmp_dir/gwc.out" || fail 'gwc could not remove a worktree with spaces'
[[ ! -e "$space_worktree" ]] || fail 'gwc left the selected worktree'
[[ -d "$other_worktree" ]] || fail 'gwc removed the unselected worktree'
[[ -d "$detached_worktree" ]] || fail 'gwc removed the detached worktree'
[[ -d "$unicode_worktree" ]] || fail 'gwc removed the unicode worktree'
grep -Fqx -- '--with-nth=2..' "$TEST_FZF_ARGS" || fail 'gwc exposed its selection key in fzf'
grep -Fqx -- '-m' "$TEST_FZF_ARGS" || fail 'gwc lost multiple selection'
grep -Fq -- "パス: $space_worktree" "$tmp_dir/gwc.out" || fail 'gwc confirmation showed the wrong path'

bare_repo="$tmp_dir/bare repo.git"
git init --bare -q "$bare_repo"
cd "$bare_repo"
actual_display=$(_gw_worktree_list_newest_first)
expected_display=$(git -c core.quotePath=false worktree list)
assert_equal "$expected_display" "$actual_display" 'bare worktree display should match git'
cd "$real_repo"

separate_repo="$tmp_dir/separate main"
separate_git="$tmp_dir/separate metadata.git"
separate_linked="$tmp_dir/separate linked"
git init -q --separate-git-dir "$separate_git" "$separate_repo"
git -C "$separate_repo" config user.name 'gwc test'
git -C "$separate_repo" config user.email 'gwc@example.invalid'
git -C "$separate_repo" commit -q --allow-empty -m 'test: initialize separate git directory'
git -C "$separate_repo" worktree add -q -b test/separate "$separate_linked"
cd "$separate_repo"
assert_equal "$(git -c core.quotePath=false worktree list | sort)" "$(_gw_worktree_list_newest_first | sort)" \
    'separate git directory worktree display should match git'

submodule_source="$tmp_dir/submodule source"
submodule_super="$tmp_dir/submodule super"
submodule_linked="$tmp_dir/submodule linked"
git init -q "$submodule_source"
git -C "$submodule_source" config user.name 'gwc test'
git -C "$submodule_source" config user.email 'gwc@example.invalid'
git -C "$submodule_source" commit -q --allow-empty -m 'test: initialize submodule source'
git init -q "$submodule_super"
git -C "$submodule_super" config user.name 'gwc test'
git -C "$submodule_super" config user.email 'gwc@example.invalid'
git -C "$submodule_super" -c protocol.file.allow=always submodule add -q "$submodule_source" child
git -C "$submodule_super" commit -qm 'test: add submodule'
git -C "$submodule_super/child" worktree add -q -b test/submodule "$submodule_linked"
cd "$submodule_super/child"
assert_equal "$(git -c core.quotePath=false worktree list | sort)" "$(_gw_worktree_list_newest_first | sort)" \
    'submodule worktree display should match git'
cd "$real_repo"

tab_worktree="$tmp_dir/tab"$'\t''worktree'
git -C "$real_repo" worktree add -q -b test/tab "$tab_worktree"
if _gw_worktree_list_newest_first > "$tmp_dir/tab.out" 2> "$tmp_dir/tab.err"; then
    fail 'a tab in a worktree path was accepted'
fi
grep -Fq 'Error: unsupported worktree path:' "$tmp_dir/tab.err" || fail 'tab path did not report an explicit error'
git -C "$real_repo" worktree remove --force "$tab_worktree"

newline_worktree="$tmp_dir/line"$'\n''break'
git -C "$real_repo" worktree add -q -b test/newline "$newline_worktree"
if _gw_worktree_list_newest_first > "$tmp_dir/newline.out" 2> "$tmp_dir/newline.err"; then
    fail 'a newline in a worktree path was accepted'
fi
grep -Eq 'Error: (malformed|unsupported) git worktree record:' "$tmp_dir/newline.err" ||
    fail 'newline path did not report an explicit error'
git -C "$real_repo" worktree remove --force "$newline_worktree"

fake_prefix="$tmp_dir/forged prefix"
fake_destination="$tmp_dir/existing unrelated"
mkdir -p "$fake_prefix" "$fake_destination"
head_oid=$(git -C "$real_repo" rev-parse HEAD)
injected_worktree="$fake_prefix"$'\n'"HEAD $head_oid"$'\n''branch refs/heads/one'$'\n\n'"worktree $fake_destination"
mkdir -p "$(dirname "$injected_worktree")"
git -C "$real_repo" worktree add -q --detach "$injected_worktree"

export TEST_FZF_SELECT="$fake_destination"
if gw > "$tmp_dir/injected.out" 2> "$tmp_dir/injected.err"; then
    fail 'gw accepted forged porcelain records from a newline path'
fi
assert_equal "$real_repo" "$PWD" 'gw moved after a forged porcelain record'
grep -Fq 'Error: invalid git worktree path:' "$tmp_dir/injected.err" ||
    fail 'forged worktree path did not report a validation error'

print 'test-gwc-worktree-list: OK'
