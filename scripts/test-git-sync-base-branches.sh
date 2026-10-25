#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_git-sync-base-branches"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

commit_file() {
  local repo=$1 name=$2
  printf '%s\n' "$name" >"$repo/$name"
  git -C "$repo" add "$name"
  git -C "$repo" commit --quiet -m "$name"
}

assert_ref() {
  local repo=$1 ref=$2 expected=$3
  [ "$(git -C "$repo" rev-parse "$ref")" = "$(git -C "$repo" rev-parse "$expected")" ] ||
    fail "$ref in $repo does not match $expected"
}

ROOT="$TMP_DIR/ghq"
OWNER_DIR="$ROOT/example.com/Acme"
REPO="$OWNER_DIR/app"
WORKTREE="$OWNER_DIR/app-prod"
SEED="$TMP_DIR/seed"

git init --quiet --bare -b main "$TMP_DIR/origin.git"
git init --quiet -b main "$SEED"
git -C "$SEED" remote add origin "$TMP_DIR/origin.git"
commit_file "$SEED" base
git -C "$SEED" push --quiet origin main main:staging main:develop main:production

mkdir -p "$OWNER_DIR"
git clone --quiet "$TMP_DIR/origin.git" "$REPO"
git -C "$REPO" branch --quiet staging origin/staging
git -C "$REPO" branch --quiet develop origin/develop
git -C "$REPO" branch --quiet master main
git -C "$REPO" worktree add --quiet "$WORKTREE" production
git -C "$REPO" checkout --quiet develop
commit_file "$REPO" develop-local
git -C "$REPO" checkout --quiet main

commit_file "$SEED" remote-update
git -C "$SEED" push --quiet origin main main:staging main:develop main:production
DEVELOP_BEFORE=$(git -C "$REPO" rev-parse develop)

mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/ghq" <<EOF
#!/usr/bin/env bash
[ "\$*" = "list --full-path" ] || exit 64
printf '%s\n' "$REPO" "$WORKTREE"
EOF
chmod +x "$TMP_DIR/bin/ghq"
export PATH="$TMP_DIR/bin:$PATH"

if bash "$SCRIPT" acme >"$TMP_DIR/out" 2>&1; then
  fail "diverged develop did not make the run fail"
fi

assert_ref "$REPO" main origin/main
[ -f "$REPO/remote-update" ] || fail "checked-out main did not update its files"
assert_ref "$REPO" staging origin/staging
assert_ref "$REPO" production origin/production
[ -f "$WORKTREE/remote-update" ] || fail "production worktree did not update its files"
[ "$(git -C "$REPO" rev-parse develop)" = "$DEVELOP_BEFORE" ] || fail "diverged develop was moved"
grep -Fq "Acme/app develop: has commits not on origin/develop" "$TMP_DIR/out" || fail "diverged develop was not reported"
grep -Fq "origin/master not found" "$TMP_DIR/out" || fail "missing origin/master was not reported"
if grep -Fq "Acme/app-prod" "$TMP_DIR/out"; then
  fail "linked worktree was treated as a repository"
fi

git -C "$REPO" branch --quiet -D develop
bash "$SCRIPT" Acme >"$TMP_DIR/out" 2>&1 || fail "up-to-date run failed: $(cat "$TMP_DIR/out")"
grep -Fq "Acme/app main: up to date" "$TMP_DIR/out" || fail "up-to-date main was not reported"

if bash "$SCRIPT" missing-owner >"$TMP_DIR/out" 2>&1; then
  fail "unknown owner did not fail"
fi
grep -Fq "no ghq repositories found for owner: missing-owner" "$TMP_DIR/out" || fail "unknown owner was not reported"

status=0
bash "$SCRIPT" >/dev/null 2>&1 || status=$?
[ "$status" -eq 2 ] || fail "missing owner argument exited with $status, expected 2"

echo "test-git-sync-base-branches: OK"
