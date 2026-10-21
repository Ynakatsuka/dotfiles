#!/usr/bin/env zsh
# Verify that zsh gwai takes its branch name from gwai-worktree-name and hands
# it to gw and the launcher. scripts/test-gwai-worktree-name.sh covers naming.

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

assert_args_equal() {
    local args_file="$1"
    shift
    local -a expected=("$@")
    local -a actual=("${(@0)$(<"$args_file")}")

    # The recorded arguments end with NUL, which leaves one empty element.
    if (( ${#actual} > 0 )) && [[ -z "${actual[-1]}" ]]; then
        actual[-1]=()
    fi
    assert_equal "${(j:|:)${(@qqq)expected}}" "${(j:|:)${(@qqq)actual}}" "unexpected arguments in $args_file"
}

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gwai-branch-name-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir"

cat >"$bin_dir/gwai-worktree-name" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\0' "$@" >"$TEST_NAMER_ARGS"
if [[ "${TEST_NAMER_STATUS:-0}" != 0 ]]; then
  printf 'Error: mocked naming failure\n' >&2
  exit "$TEST_NAMER_STATUS"
fi
printf '261017-パスワード再設定修正\n'
MOCK
chmod +x "$bin_dir/gwai-worktree-name"

PATH="$bin_dir:$PATH"
export TEST_NAMER_ARGS="$tmp_dir/namer.args"

gw() {
    printf '%s\0' "$@" >"$tmp_dir/gw.args"
}

cl() {
    printf '%s\0' "$@" >"$tmp_dir/cl.args"
}

cdx() {
    printf '%s\0' "$@" >"$tmp_dir/cdx.args"
}

reset_records() {
    rm -f -- "$tmp_dir"/*.args(N)
}

# Run outside any git repository so gwai always creates a worktree through gw.
cd "$tmp_dir"

# A prompt that starts with "-" must reach the helper as a prompt, not an option.
prompt='-x looks like an option'
gwai "$prompt" </dev/null >"$tmp_dir/out" 2>&1 || fail "gwai failed: $(<"$tmp_dir/out")"
assert_args_equal "$tmp_dir/namer.args" -- "$prompt"
assert_args_equal "$tmp_dir/gw.args" '261017-パスワード再設定修正'
assert_args_equal "$tmp_dir/cl.args" "$prompt"
[[ ! -e "$tmp_dir/cdx.args" ]] || fail "gwai without -x started cdx"

reset_records
print -r -- 'piped details' | gwai -x 'fix login' >"$tmp_dir/out" 2>&1 ||
    fail "gwai -x failed: $(<"$tmp_dir/out")"
expected_prompt=$'fix login\npiped details'
assert_args_equal "$tmp_dir/namer.args" -- "$expected_prompt"
assert_args_equal "$tmp_dir/gw.args" '261017-パスワード再設定修正'
assert_args_equal "$tmp_dir/cdx.args" "$expected_prompt"
[[ ! -e "$tmp_dir/cl.args" ]] || fail "gwai -x started cl"

reset_records
if TEST_NAMER_STATUS=1 gwai 'naming fails' </dev/null >"$tmp_dir/out" 2>&1; then
    fail "gwai succeeded although naming failed"
fi
grep -Fq 'mocked naming failure' "$tmp_dir/out" || fail "naming failure was not surfaced: $(<"$tmp_dir/out")"
[[ ! -e "$tmp_dir/gw.args" ]] || fail "gwai ran gw after naming failed"
[[ ! -e "$tmp_dir/cl.args" ]] || fail "gwai started cl after naming failed"

print 'test-gwai-branch-name: OK'
