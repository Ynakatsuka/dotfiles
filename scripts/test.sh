#!/usr/bin/env bash
# Run the repository's local test suites from one explicit registry.
set -euo pipefail

case "${BASH_SOURCE[0]}" in
  */*) script_dir=${BASH_SOURCE[0]%/*} ;;
  *) script_dir=. ;;
esac
repo_root=$(cd "$script_dir/.." && pwd -P)
cd "$repo_root"

names=()
runners=()
paths=()
required_tools=()
platforms=()

register() {
  names+=("$1")
  runners+=("$2")
  paths+=("$3")
  required_tools+=("$4")
  platforms+=("${5:-Linux,Darwin}")
}

# name, runner, source path, external tools, optional supported platform.
register test-cmux-agent-board-auto-title bash scripts/test-cmux-agent-board-auto-title.sh 'bash chezmoi jq python3'
register test-cmux-agent-board-diff-open bash scripts/test-cmux-agent-board-diff-open.sh 'bash git python3'
register test-cmux-agent-board-diff-refresh bash scripts/test-cmux-agent-board-diff-refresh.sh 'bash git jq python3'
register test-cmux-agent-board-state bash scripts/test-cmux-agent-board-state.sh 'bash chezmoi jq python3 zsh'
register test-cmux-agent-board-usage bash scripts/test-cmux-agent-board-usage.sh 'bash jq python3'
register test-cmux-resume-all-codex-sessions bash scripts/test-cmux-resume-all-codex-sessions.sh 'bash jq'
register test-codex-config bash scripts/test-codex-config.sh 'bash chezmoi jq'
register test-codex-skills-link bash scripts/test-codex-skills-link.sh 'bash chezmoi'
register test-delegation bash scripts/test-delegation.sh 'bash chezmoi jq python3'
register test-disk-tree bash scripts/test-disk-tree.sh 'bash python3'
register test-dotfiles-brew-upgrade bash scripts/test-dotfiles-brew-upgrade.sh 'bash'
register test-dotfiles-mise-up bash scripts/test-dotfiles-mise-up.sh 'bash jq'
register test-gwai-branch-name zsh scripts/test-gwai-branch-name.zsh 'zsh'
register test-gwai-cmux-worktree-capture bash scripts/test-gwai-cmux-worktree-capture.sh 'bash git'
register test-gwai-orca bash scripts/test-gwai-orca.sh 'bash git jq'
register test-gwc-worktree-list zsh scripts/test-gwc-worktree-list.zsh 'zsh git'
register test-handoff-context bash scripts/test-handoff-context.sh 'bash git'
register test-my-pr-review-input bash scripts/test-my-pr-review-input.sh 'bash git jq'
register test-my-pr-worktree-move bash scripts/test-my-pr-worktree-move.sh 'bash git'
register test-my-skill-creator bash scripts/test-my-skill-creator.sh 'bash python3 uv'
register test-prune-old-worktrees bash scripts/test-prune-old-worktrees.sh 'bash git python3' Linux
register test-rtk-rewrite-hook bash scripts/test-rtk-rewrite-hook.sh 'bash jq'
register test-runner bash scripts/test-runner.sh 'bash'
register test-session-resume bash scripts/test-session-resume.sh 'bash python3 zsh'
register test-update-bootstrap bash scripts/test-update-bootstrap.sh 'bash awk mise'
register my-japanese-editor unittest home/dot_claude/skills/my-japanese-editor/tests 'python3'
register my-handoff node-handoff home/dot_claude/skills/my-handoff/scripts/launch-orca-handoff.test.mjs 'node bash git jq'

find_name() {
  local wanted=$1 index
  for index in "${!names[@]}"; do
    if [[ "${names[$index]}" == "$wanted" ]]; then
      printf '%s\n' "$index"
      return 0
    fi
  done
  return 1
}

validate_registry() {
  local index candidate name
  for index in "${!names[@]}"; do
    if [[ ! -e "$repo_root/${paths[$index]}" ]]; then
      printf 'test.sh: registered test is missing: %s (%s)\n' "${names[$index]}" "${paths[$index]}" >&2
      return 1
    fi
    case "${runners[$index]}" in
      bash | zsh | unittest | node-handoff) ;;
      *)
        printf 'test.sh: unknown runner for %s: %s\n' "${names[$index]}" "${runners[$index]}" >&2
        return 1
        ;;
    esac
  done
  for candidate in "$repo_root"/scripts/test-*.sh "$repo_root"/scripts/test-*.zsh; do
    [[ -f "$candidate" ]] || continue
    name=${candidate##*/}
    name=${name%.*}
    if ! find_name "$name" >/dev/null; then
      printf 'test.sh: unregistered test: scripts/%s\n' "${candidate##*/}" >&2
      return 1
    fi
  done
}

run_case() {
  local index=$1 path="$repo_root/${paths[$1]}"
  case "${runners[$index]}" in
    bash) bash "$path" ;;
    zsh) zsh "$path" ;;
    unittest) python3 -B -m unittest discover -s "$path" -p 'test_*.py' ;;
    node-handoff)
      mkdir "$log_dir/handoff" || return
      cp "$path" "$log_dir/handoff/launch-orca-handoff.test.mjs" || return
      cp "$repo_root/home/dot_claude/skills/my-handoff/scripts/executable_launch-orca-handoff.sh" \
        "$log_dir/handoff/launch-orca-handoff.sh" || return
      node --test "$log_dir/handoff/launch-orca-handoff.test.mjs"
      ;;
  esac
}

usage() {
  printf 'Usage: bash scripts/test.sh [--list | TEST_NAME...]\n' >&2
}

case "$OSTYPE" in
  linux*) platform=Linux ;;
  darwin*) platform=Darwin ;;
  *)
    printf 'test.sh: unsupported OS: %s\n' "$OSTYPE" >&2
    exit 2
    ;;
esac
validate_registry || exit 2

if [[ "${1:-}" == --list ]]; then
  if [[ $# -ne 1 ]]; then
    usage
    exit 2
  fi
  printf '%s\n' "${names[@]}"
  exit 0
fi

selected=()
all_tests=0
if [[ $# -eq 0 ]]; then
  all_tests=1
  selected=("${!names[@]}")
else
  for name in "$@"; do
    if ! index=$(find_name "$name"); then
      printf 'test.sh: unknown test: %s\n' "$name" >&2
      usage
      exit 2
    fi
    selected+=("$index")
  done
fi

supported=()
skipped=0
for index in "${selected[@]}"; do
  if [[ ",${platforms[$index]}," == *",$platform,"* ]]; then
    supported+=("$index")
  elif [[ "$all_tests" -eq 1 ]]; then
    printf 'SKIP %s (requires %s)\n' "${names[$index]}" "${platforms[$index]}"
    skipped=$((skipped + 1))
  else
    printf 'test.sh: %s requires %s (current: %s)\n' "${names[$index]}" "${platforms[$index]}" "$platform" >&2
    exit 2
  fi
done
selected=("${supported[@]}")

missing=0
for index in "${selected[@]}"; do
  read -r -a tools <<<"${required_tools[$index]}"
  for tool in "${tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'test.sh: %s requires missing tool: %s\n' "${names[$index]}" "$tool" >&2
      missing=1
    fi
  done
done
[[ "$missing" -eq 0 ]] || exit 2

log_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")
trap 'rm -rf "$log_dir"' EXIT
failures=0
for index in "${selected[@]}"; do
  name=${names[$index]}
  if run_case "$index" >"$log_dir/$name.log" 2>&1; then
    printf 'PASS %s\n' "$name"
  else
    status=$?
    printf 'FAIL %s (exit %s)\n' "$name" "$status" >&2
    cat "$log_dir/$name.log" >&2
    failures=$((failures + 1))
  fi
done
printf 'test.sh: %s passed, %s failed, %s skipped\n' "$((${#selected[@]} - failures))" "$failures" "$skipped"
[[ "$failures" -eq 0 ]]
