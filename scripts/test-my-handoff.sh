#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if (($# > 1)); then
  echo "Usage: test-my-handoff.sh [my-handoff-skill-root]" >&2
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

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/my-handoff-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local output=$1
  local expected=$2
  [[ "$output" == *"$expected"* ]] || fail "output does not contain: $expected"
}

test_repo="$tmp_dir/repo with space"
mkdir -p "$test_repo"
git -C "$test_repo" init -q
git -C "$test_repo" config user.name "Test User"
git -C "$test_repo" config user.email "test@example.com"
git -C "$test_repo" checkout -qb feature/handoff
printf 'tracked\n' >"$test_repo/tracked.txt"
git -C "$test_repo" add tracked.txt
git -C "$test_repo" commit -qm "test: add fixture"

printf 'changed\n' >>"$test_repo/tracked.txt"
printf 'untracked\n' >"$test_repo/untracked.txt"
local_output=$(cd "$test_repo" && /bin/bash "$handoff_script" local)
assert_contains "$local_output" "handoff_mode=local"
assert_contains "$local_output" "repo_root="
assert_contains "$local_output" "head_state=branch"
assert_contains "$local_output" "branch=feature/handoff"
assert_contains "$local_output" "working_tree=dirty"

git -C "$test_repo" restore tracked.txt
rm "$test_repo/untracked.txt"
head_sha=$(git -C "$test_repo" rev-parse HEAD)
git -C "$test_repo" remote add origin https://github.com/Owner/Repo.git
git -C "$test_repo" config branch.feature/handoff.remote origin
git -C "$test_repo" config branch.feature/handoff.merge refs/heads/feature/handoff
git -C "$test_repo" update-ref refs/remotes/origin/feature/handoff "$head_sha"

fake_bin="$tmp_dir/fake-bin"
mkdir -p "$fake_bin"
real_git=$(command -v git)

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "ls-remote" ]]; then
  printf '%s\t%s\n' "$FAKE_REMOTE_SHA" "refs/heads/feature/handoff"
  exit 0
fi
exec "$REAL_GIT" "$@"
EOF

cat >"$fake_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t%s\t%s\t%s\t%s\n' \
  "https://github.com/Owner/Repo/pull/1" \
  "$FAKE_REMOTE_SHA" \
  "feature/handoff" \
  "owner/repo" \
  "main"
EOF
chmod +x "$fake_bin/git" "$fake_bin/gh"

remote_output=$(
  cd "$test_repo"
  PATH="$fake_bin:$PATH" \
    REAL_GIT="$real_git" \
    FAKE_REMOTE_SHA="$head_sha" \
    /bin/bash "$handoff_script"
)
assert_contains "$remote_output" "handoff_mode=remote"
assert_contains "$remote_output" "share_kind=pr"
assert_contains "$remote_output" "branch=feature/handoff"
assert_contains "$remote_output" "commit=$head_sha"
assert_contains "$remote_output" "pr_url=https://github.com/Owner/Repo/pull/1"

if (cd "$test_repo" && /bin/bash "$handoff_script" unsupported >/dev/null 2>&1); then
  fail "unsupported mode unexpectedly succeeded"
fi

if grep -Fq '${candidate_repo,,}' "$handoff_script"; then
  fail "Bash 4 lowercase expansion remains in the handoff script"
fi

echo "PASS: my-handoff local and remote modes"
