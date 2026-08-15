#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SCRIPT="$REPO_ROOT/home/dot_local/libexec/cmux/executable_agent-board-diff-open"

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/cmux-agent-board-diff-open-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

git_repo="$test_dir/repository"
mock_cmux="$test_dir/cmux"
calls_file="$test_dir/calls"
patch_copy="$test_dir/change.patch"

git init -q "$git_repo"
git_repo=$(cd "$git_repo" && pwd -P)
git -C "$git_repo" config user.email 'test@example.com'
git -C "$git_repo" config user.name 'Test User'
printf 'before\n' >"$git_repo/tracked.txt"
printf 'deleted\n' >"$git_repo/deleted.txt"
printf '# Before\n' >"$git_repo/README.md"
git -C "$git_repo" add tracked.txt deleted.txt README.md
git -C "$git_repo" commit -qm 'initial commit'
printf 'after\n' >"$git_repo/tracked.txt"
printf 'untracked\n' >"$git_repo/untracked.txt"
printf '# After\n\nRendered content.\n' >"$git_repo/README.md"
rm "$git_repo/deleted.txt"

cat >"$mock_cmux" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s ' "$@" >>"$MOCK_CALLS_FILE"
printf '\n' >>"$MOCK_CALLS_FILE"
if [[ "$*" == 'rpc surface.list '* ]]; then
  printf '{"surfaces":[{"id":"existing-diff-surface","type":"browser","title":"Agent Board Diff: previous.txt","pane_id":"pane-id","pane_ref":"pane:1","index_in_pane":0},{"id":"surface-id","ref":"surface:1","type":"terminal","title":"Diff helper","pane_id":"pane-id","pane_ref":"pane:1","index_in_pane":1}]}'
  exit 0
fi
if [[ "${1:-}" == '--json' && "${4:-}" == 'diff' ]]; then
  cp "${5:-}" "$MOCK_PATCH_COPY"
  printf '{"surface_id":"diff-surface"}'
  exit 0
fi
if [[ "${1:-}" == '--json' && "${4:-}" == 'markdown' ]]; then
  printf '{"surface_id":"markdown-surface"}'
  exit 0
fi
if [[ "${1:-}" == 'rename-tab' ]]; then
  exit 0
fi
if [[ "${1:-}" == 'move-surface' ]]; then
  exit 0
fi
if [[ "${1:-}" == 'close-surface' ]]; then
  exit 0
fi
printf 'unexpected cmux arguments: %s\n' "$*" >&2
exit 1
MOCK
chmod +x "$mock_cmux"

run_open() {
  CMUX_BIN="$mock_cmux" \
    MOCK_CALLS_FILE="$calls_file" \
    MOCK_PATCH_COPY="$patch_copy" \
    CMUX_WORKSPACE_ID='workspace-id' \
    CMUX_SURFACE_ID='surface-id' \
    "$SCRIPT" "$@"
}

(
  cd "$git_repo"
  run_open 'dHJhY2tlZC50eHQ'
)
grep -Fq 'diff --git a/tracked.txt b/tracked.txt' "$patch_copy"
grep -Fq -- '--focus false --title Agent Board Diff: tracked.txt' "$calls_file"
grep -Fq -- 'move-surface --surface diff-surface --pane pane-id --workspace workspace-id --before existing-diff-surface --focus true' "$calls_file"
grep -Fq -- 'close-surface --surface existing-diff-surface --workspace workspace-id' "$calls_file"

(
  cd "$git_repo"
  run_open 'dW50cmFja2VkLnR4dA'
)
grep -Fq 'diff --git a/untracked.txt b/untracked.txt' "$patch_copy"
grep -Fq 'new file mode' "$patch_copy"

(
  cd "$git_repo"
  run_open 'ZGVsZXRlZC50eHQ'
)
grep -Fq 'diff --git a/deleted.txt b/deleted.txt' "$patch_copy"
grep -Fq 'deleted file mode' "$patch_copy"

(
  cd "$git_repo"
  run_open 'UkVBRE1FLm1k' --mode markdown
)
grep -Fq -- "markdown open $git_repo/README.md --workspace workspace-id --surface surface-id --focus true" "$calls_file"
grep -Fq -- 'rename-tab --surface markdown-surface --workspace workspace-id Agent Board Diff: README.md (Markdown)' "$calls_file"
if grep -Fq -- 'move-surface --surface markdown-surface' "$calls_file"; then
  printf 'Markdown surface was unexpectedly moved after opening\n' >&2
  exit 1
fi

if (
  cd "$git_repo"
  run_open 'dHJhY2tlZC50eHQ' --mode markdown
) >/dev/null 2>&1; then
  printf 'non-Markdown file unexpectedly opened in Markdown mode\n' >&2
  exit 1
fi

if (
  cd "$git_repo"
  run_open 'not-valid!'
) >/dev/null 2>&1; then
  printf 'invalid path token unexpectedly succeeded\n' >&2
  exit 1
fi

if (
  cd "$git_repo"
  run_open 'Li4vb3V0c2lkZQ'
) >/dev/null 2>&1; then
  printf 'path traversal unexpectedly succeeded\n' >&2
  exit 1
fi

git -C "$git_repo" checkout -- tracked.txt
if (
  cd "$git_repo"
  run_open 'dHJhY2tlZC50eHQ'
) >/dev/null 2>&1; then
  printf 'clean file unexpectedly opened\n' >&2
  exit 1
fi

printf 'cmux Agent Board diff open tests passed\n'
