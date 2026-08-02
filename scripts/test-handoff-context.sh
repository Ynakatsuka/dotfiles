#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if (($# > 1)); then
  echo "Usage: test-handoff-context.sh [my-handoff-skill-root]" >&2
  exit 1
fi
skill_root=${1:-"$repo_root/home/dot_claude/skills/my-handoff"}
source_script="$skill_root/scripts/executable_collect-handoff-context.sh"
deployed_script="$skill_root/scripts/collect-handoff-context.sh"

if [[ -f "$source_script" && ! -e "$deployed_script" ]]; then
  handoff_script=$source_script
elif [[ -f "$deployed_script" && ! -e "$source_script" ]]; then
  handoff_script=$deployed_script
else
  echo "FAIL: expected exactly one handoff script path" >&2
  exit 1
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/handoff-context-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

test_repo="$tmp_dir/repo"
fake_bin="$tmp_dir/fake-bin"
real_git=$(command -v git)
mkdir -p "$test_repo" "$fake_bin"

git -C "$test_repo" init -q
git -C "$test_repo" config user.name "my-handoff test"
git -C "$test_repo" config user.email "my-handoff@example.invalid"
printf 'fixture\n' >"$test_repo/fixture.txt"
git -C "$test_repo" add fixture.txt
git -C "$test_repo" commit -qm "test: add fixture"
git -C "$test_repo" branch -M feature/handoff
git -C "$test_repo" remote add origin https://github.com/Ynakatsuka/dotfiles.git
git -C "$test_repo" update-ref refs/remotes/origin/feature/handoff HEAD
git -C "$test_repo" config branch.feature/handoff.remote origin
git -C "$test_repo" config branch.feature/handoff.merge refs/heads/feature/handoff
test_sha=$(git -C "$test_repo" rev-parse HEAD)

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "ls-remote" ]]; then
  printf '%s\trefs/heads/feature/handoff\n' "${HANDOFF_TEST_SHA:?}"
  exit 0
fi
exec "${HANDOFF_REAL_GIT:?}" "$@"
EOF

cat >"$fake_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-} ${2:-}" != "pr list" ]]; then
  echo "unexpected gh invocation: $*" >&2
  exit 2
fi
printf 'https://github.com/Ynakatsuka/dotfiles/pull/123\t%s\tfeature/handoff\tynakatsuka/dotfiles\tmain\n' \
  "${HANDOFF_TEST_SHA:?}"
EOF
chmod +x "$fake_bin/git" "$fake_bin/gh"

output=$(
  cd "$test_repo"
  PATH="$fake_bin:$PATH" \
    HANDOFF_REAL_GIT="$real_git" \
    HANDOFF_TEST_SHA="$test_sha" \
    /bin/bash "$handoff_script"
)

grep -Fqx 'share_kind=pr' <<<"$output" || {
  echo "FAIL: handoff script did not select the open PR" >&2
  exit 1
}
grep -Fqx 'pr_url=https://github.com/Ynakatsuka/dotfiles/pull/123' <<<"$output" || {
  echo "FAIL: handoff script did not report the open PR URL" >&2
  exit 1
}

echo "test-handoff-context: OK"
