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

assert_file_contains() {
    local file_path="$1"
    local expected="$2"

    grep -Fq -- "$expected" "$file_path" ||
        fail "$file_path does not contain: $expected"
}

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gwai-branch-name-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

codex() {
    print -rl -- "$@" >"$tmp_dir/codex.args"

    local output_file=""
    local i=1
    while ((i <= $#)); do
        if [[ "${argv[$i]}" = "--output-last-message" ]]; then
            ((i++))
            output_file="${argv[$i]}"
            break
        fi
        ((i++))
    done

    [[ -n "$output_file" ]] || fail "codex did not receive --output-last-message"
    print -r -- "${TEST_CODEX_OUTPUT:-}" >"$output_file"
    return "${TEST_CODEX_STATUS:-0}"
}

claude() {
    print -rl -- "$@" >"$tmp_dir/claude.args"
    print -r -- "${TEST_CLAUDE_OUTPUT:-}"
    return "${TEST_CLAUDE_STATUS:-0}"
}

date() {
    if [[ "${1:-}" = '+%y%m%d' ]]; then
        print '260811'
        return 0
    fi
    command date "$@"
}

slack_url='https://example.slack.com/archives/C01234567/p1234567890123456'
TEST_CODEX_OUTPUT='fix resolve-slack-task-context'
TEST_CODEX_STATUS=0
TEST_CLAUDE_OUTPUT='chore unused-fallback'
TEST_CLAUDE_STATUS=0
export TEST_CODEX_OUTPUT TEST_CODEX_STATUS TEST_CLAUDE_OUTPUT TEST_CLAUDE_STATUS

actual=$(_gwai_generate_branch_name "$slack_url" 2>"$tmp_dir/slack-url.err")
[[ "$actual" =~ '^260811-chore-[0-9a-f]{8}$' ]] ||
    fail "Slack URL alone did not produce a dated random name: $actual"
assert_file_contains "$tmp_dir/slack-url.err" 'Slack URL has no descriptive text'
[[ ! -e "$tmp_dir/codex.args" ]] || fail "Slack URL alone was sent to Codex"
[[ ! -e "$tmp_dir/claude.args" ]] || fail "Slack URL alone was sent to Claude"

actual=$(_gwai_generate_branch_name "[resolve task context]($slack_url)")
assert_equal '260811-fix-resolve-slack-task-context' "$actual" "Codex output should become a dated branch name"
assert_file_contains "$tmp_dir/codex.args" 'gpt-5.6-luna'
assert_file_contains "$tmp_dir/codex.args" 'model_reasoning_effort="low"'
assert_file_contains "$tmp_dir/codex.args" '--sandbox'
assert_file_contains "$tmp_dir/codex.args" 'read-only'
assert_file_contains "$tmp_dir/codex.args" 'apps'
assert_file_contains "$tmp_dir/codex.args" 'plugins'
assert_file_contains "$tmp_dir/codex.args" 'shell_tool'
assert_file_contains "$tmp_dir/codex.args" 'network_access=false'
assert_file_contains "$tmp_dir/codex.args" 'Do not open, fetch, or read linked content'
assert_file_contains "$tmp_dir/codex.args" 'Do not read a referenced Slack message or thread'
assert_file_contains "$tmp_dir/codex.args" "$slack_url"
[[ ! -e "$tmp_dir/claude.args" ]] || fail "Claude fallback ran after valid Codex output"

TEST_CODEX_STATUS=1
TEST_CLAUDE_OUTPUT='feat use-haiku-fallback'
export TEST_CODEX_STATUS TEST_CLAUDE_OUTPUT
actual=$(_gwai_generate_branch_name 'fallback task')
assert_equal '260811-feat-use-haiku-fallback' "$actual" "Claude should return a dated name after Codex failure"
assert_file_contains "$tmp_dir/claude.args" '--model'
assert_file_contains "$tmp_dir/claude.args" 'haiku'

TEST_CODEX_STATUS=0
TEST_CODEX_OUTPUT='not a valid branch response'
TEST_CLAUDE_OUTPUT='docs handle-invalid-codex-output'
export TEST_CODEX_STATUS TEST_CODEX_OUTPUT TEST_CLAUDE_OUTPUT
actual=$(_gwai_generate_branch_name 'invalid output task')
assert_equal '260811-docs-handle-invalid-codex-output' "$actual" "Claude should return a dated name after invalid Codex output"

TEST_CODEX_OUTPUT='still invalid output'
TEST_CLAUDE_OUTPUT='also invalid output'
export TEST_CODEX_OUTPUT TEST_CLAUDE_OUTPUT
actual=$(_gwai_generate_branch_name 'double failure task' 2>"$tmp_dir/failure.err")
[[ "$actual" =~ '^260811-chore-[0-9a-f]{8}$' ]] ||
    fail "invalid output from both providers did not produce a dated random name: $actual"
assert_file_contains "$tmp_dir/failure.err" 'using a random branch name'

print 'test-gwai-branch-name: OK'
