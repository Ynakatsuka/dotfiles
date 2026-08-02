#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if (($# > 1)); then
  echo "Usage: test-my-pr-review-input.sh [my-pr-skill-root]" >&2
  exit 1
fi
skill_root=${1:-"$repo_root/home/dot_claude/skills/my-pr"}
resolve_skill_script() {
  local script_name=$1
  local source_path="$skill_root/scripts/executable_${script_name}"
  local deployed_path="$skill_root/scripts/$script_name"

  if [[ -f "$source_path" && ! -e "$deployed_path" ]]; then
    printf '%s\n' "$source_path"
    return
  fi
  if [[ -f "$deployed_path" && ! -e "$source_path" ]]; then
    printf '%s\n' "$deployed_path"
    return
  fi
  echo "ERROR: expected exactly one my-pr script path: $source_path or $deployed_path" >&2
  return 1
}

split_script=$(resolve_skill_script split-review-chunks.sh)
prepare_script=$(resolve_skill_script prepare-review-artifacts.sh)
context_script=$(resolve_skill_script prepare-pr-context.sh)
reviewer_agent="$repo_root/home/dot_codex/agents/reviewer.toml"
simplifier_agent="$repo_root/home/dot_codex/agents/simplifier.toml"
simplifier_apply_agent="$repo_root/home/dot_codex/agents/simplifier_apply.toml"

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/my-pr-review-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file=$1
  local pattern=$2

  grep -Fq -- "$pattern" "$file" || fail "$file does not contain: $pattern"
}

assert_file_not_contains() {
  local file=$1
  local pattern=$2

  if grep -Fq -- "$pattern" "$file"; then
    fail "$file unexpectedly contains: $pattern"
  fi
}

assert_file_line_count() {
  local file=$1
  local line=$2
  local expected=$3
  local actual

  actual=$(awk -v expected_line="$line" '$0 == expected_line { count++ } END { print count + 0 }' "$file")
  [[ "$actual" == "$expected" ]] ||
    fail "$file contains $actual exact '$line' lines; expected $expected"
}

assert_skill_tree_not_matching() {
  local pattern=$1
  local description=$2
  local matches="$tmp_dir/forbidden-skill-reference.txt"

  if rg -n -i -e "$pattern" "$skill_root" >"$matches"; then
    cat "$matches" >&2
    fail "my-pr skill tree still contains $description"
  fi
}

test_chunking() {
  local test_repo="$tmp_dir/repo with space"
  local artifact_dir
  local artifact_env
  local base_ref

  mkdir -p "$test_repo"
  git -C "$test_repo" init -q
  git -C "$test_repo" config user.name "Test User"
  git -C "$test_repo" config user.email "test@example.com"
  printf 'base\n' >"$test_repo/base.txt"
  git -C "$test_repo" add base.txt
  git -C "$test_repo" commit -qm "chore: add base"
  base_ref=$(git -C "$test_repo" rev-parse HEAD)

  mkdir -p "$test_repo/docs" "$test_repo/src"
  for file in "docs/alpha.md" "docs/beta.md" "src/file one.txt" "src/file-two.txt" "src/日本語.txt"; do
    awk -v prefix="$file" 'BEGIN {
      for (line = 1; line <= 16; line++) {
        printf "%s line %02d ", prefix, line
        for (column = 1; column <= 45; column++) {
          printf "abcdefghij"
        }
        printf "\n"
      }
    }' >"$test_repo/$file"
  done
  git -C "$test_repo" add docs src
  git -C "$test_repo" commit -qm "test: add review fixtures"

  artifact_env=$(
    cd "$test_repo"
    /bin/bash "$prepare_script" "$base_ref" 2>"$tmp_dir/prepare-error.txt"
  )
  [[ "$artifact_env" == /*/artifact.env ]] ||
    fail "prepare script did not return an absolute artifact env path: $artifact_env"
  artifact_dir=$(dirname "$artifact_env")
  (
    unset MY_PR_ARTIFACT_DIR MY_PR_ARTIFACT_ENV MY_PR_REVIEW_BYTES
    # shellcheck source=/dev/null
    source "$artifact_env"
    printf '%s\n' "$MY_PR_REVIEW_BYTES" >"$tmp_dir/review-bytes.txt"
  )
  [[ "$(cat "$tmp_dir/review-bytes.txt")" =~ ^[1-9][0-9]*$ ]] || fail "review byte count was not exported"
  assert_file_contains "$artifact_dir/changed-files.txt" "src/日本語.txt"

  mkdir -p "$tmp_dir/fake-bin"
  cat >"$tmp_dir/fake-bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-} ${2:-}" == "pr view" ]]; then
  echo "no pull requests found for branch" >&2
  exit 1
fi
echo "unexpected gh invocation: $*" >&2
exit 2
EOF
  chmod +x "$tmp_dir/fake-bin/gh"
  (
    cd "$test_repo"
    env -u MY_PR_ARTIFACT_DIR -u MY_PR_ARTIFACT_ENV \
      PATH="$tmp_dir/fake-bin:$PATH" \
      /bin/bash "$context_script" "$artifact_env" >"$tmp_dir/context-output.txt"
  )
  [[ "$(cat "$tmp_dir/context-output.txt")" == "$artifact_env" ]] ||
    fail "context script did not return the artifact env path"
  assert_file_contains "$artifact_env" "export MY_PR_CONTEXT="
  assert_file_contains "$artifact_dir/pr-context.md" "State: no existing PR"

  (
    cd "$test_repo"
    env -u MY_PR_ARTIFACT_DIR -u MY_PR_BASE_REF \
      MY_PR_REVIEW_CHUNK_MAX_BYTES=20000 \
      /bin/bash "$split_script" "$artifact_env" >"$tmp_dir/chunk-output.txt"
  )
  [[ "$(cat "$tmp_dir/chunk-output.txt")" == "$artifact_env" ]] ||
    fail "chunk script did not return the artifact env path"
  assert_file_contains "$artifact_env" "export MY_PR_CHUNK_MANIFEST="

  local manifest="$artifact_dir/chunks/manifest.txt"
  [[ -s "$manifest" ]] || fail "chunk manifest is empty"
  local chunk_count
  chunk_count=$(wc -l <"$manifest" | tr -d ' ')
  ((chunk_count >= 4)) || fail "expected at least four byte-bounded chunks, got $chunk_count"

  while read -r chunk_id chunk_lines chunk_path; do
    [[ -n "$chunk_id" && -n "$chunk_lines" && -n "$chunk_path" ]] || fail "invalid manifest row"
    local bytes
    bytes=$(wc -c <"$chunk_path" | tr -d ' ')
    ((bytes <= 20000)) || fail "chunk $chunk_id exceeds byte limit: $bytes"
  done <"$manifest"

  cmp -s "$artifact_dir/chunks/all-covered.txt" "$artifact_dir/chunks/expected-covered.txt" ||
    fail "chunk coverage mismatch"
  assert_file_contains "$artifact_dir/chunks/all-covered.txt" "src/file one.txt"

  if (
    cd "$test_repo"
    env -u MY_PR_ARTIFACT_DIR -u MY_PR_BASE_REF \
      MY_PR_REVIEW_CHUNK_MAX_BYTES=196609 \
      /bin/bash "$split_script" "$artifact_env" \
      >"$tmp_dir/raised-chunk-cap-output.txt" 2>"$tmp_dir/raised-chunk-cap-error.txt"
  ); then
    fail "raised chunk cap unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/raised-chunk-cap-error.txt" "8193 through 196608"

  awk 'BEGIN { for (i = 1; i <= 11000; i++) print "+0123456789" }' >"$test_repo/docs/oversized.md"
  git -C "$test_repo" add docs/oversized.md
  git -C "$test_repo" commit -qm "test: add oversized review fixture"
  local oversized_artifact
  local oversized_env
  oversized_env=$(
    cd "$test_repo"
    /bin/bash "$prepare_script" "$base_ref" 2>"$tmp_dir/oversized-prepare-error.txt"
  )
  oversized_artifact=$(dirname "$oversized_env")
  (
    cd "$test_repo"
    env -u MY_PR_ARTIFACT_DIR -u MY_PR_BASE_REF \
      /bin/bash "$split_script" "$oversized_env" \
      >"$tmp_dir/oversized-file-output.txt" 2>"$tmp_dir/oversized-file-error.txt"
  )
  assert_file_contains "$oversized_artifact/chunks/all-covered.txt" "docs/oversized.md"
  [[ ! -s "$oversized_artifact/chunks/skipped-files.txt" ]] ||
    fail "a file below the raised default limit was skipped"

  awk 'BEGIN { for (i = 1; i <= 22000; i++) print "+0123456789" }' >"$test_repo/docs/too-large.json"
  git -C "$test_repo" add docs/too-large.json
  git -C "$test_repo" commit -qm "test: add skipped review fixture"
  local skipped_artifact
  local skipped_env
  skipped_env=$(
    cd "$test_repo"
    /bin/bash "$prepare_script" "$base_ref" 2>"$tmp_dir/skipped-prepare-error.txt"
  )
  skipped_artifact=$(dirname "$skipped_env")
  (
    cd "$test_repo"
    env -u MY_PR_ARTIFACT_DIR -u MY_PR_BASE_REF \
      /bin/bash "$split_script" "$skipped_env" \
      >"$tmp_dir/skipped-file-output.txt" 2>"$tmp_dir/skipped-file-error.txt"
  )
  assert_file_contains "$skipped_artifact/chunks/skipped-files.txt" "docs/too-large.json"
  assert_file_contains "$skipped_artifact/chunks/skipped-files-summary.txt" "bytes: docs/too-large.json"
  assert_file_contains "$skipped_artifact/chunks/all-covered.txt" "docs/oversized.md"
  assert_file_not_contains "$skipped_artifact/chunks/all-covered.txt" "docs/too-large.json"
  assert_file_contains "$tmp_dir/skipped-file-error.txt" "skipping oversized file diff"

  local skipped_only_repo="$tmp_dir/skipped only repo"
  local skipped_only_base
  local skipped_only_artifact
  local skipped_only_env
  mkdir -p "$skipped_only_repo"
  git -C "$skipped_only_repo" init -q
  git -C "$skipped_only_repo" config user.name "Test User"
  git -C "$skipped_only_repo" config user.email "test@example.com"
  printf 'base\n' >"$skipped_only_repo/base.txt"
  git -C "$skipped_only_repo" add base.txt
  git -C "$skipped_only_repo" commit -qm "chore: add base"
  skipped_only_base=$(git -C "$skipped_only_repo" rev-parse HEAD)
  awk 'BEGIN { for (i = 1; i <= 22000; i++) print "+0123456789" }' >"$skipped_only_repo/only-large.json"
  git -C "$skipped_only_repo" add only-large.json
  git -C "$skipped_only_repo" commit -qm "test: add only skipped fixture"
  skipped_only_env=$(
    cd "$skipped_only_repo"
    /bin/bash "$prepare_script" "$skipped_only_base" 2>"$tmp_dir/skipped-only-prepare-error.txt"
  )
  skipped_only_artifact=$(dirname "$skipped_only_env")
  (
    cd "$skipped_only_repo"
    env -u MY_PR_ARTIFACT_DIR -u MY_PR_BASE_REF \
      /bin/bash "$split_script" "$skipped_only_env" \
      >"$tmp_dir/skipped-only-output.txt" 2>"$tmp_dir/skipped-only-error.txt"
  )
  [[ ! -s "$skipped_only_artifact/chunks/manifest.txt" ]] ||
    fail "an all-skipped diff unexpectedly produced review chunks"
  [[ ! -s "$skipped_only_artifact/chunks/reviewable-files.txt" ]] ||
    fail "an all-skipped diff unexpectedly produced reviewable files"
  assert_file_contains "$skipped_only_artifact/chunks/skipped-files.txt" "only-large.json"

  local newline_file=$'src/line\nbreak.txt'
  printf 'newline path\n' >"$test_repo/$newline_file"
  git -C "$test_repo" add -- "$newline_file"
  git -C "$test_repo" commit -qm "test: add unsupported newline path"
  if (
    cd "$test_repo"
    /bin/bash "$prepare_script" "$base_ref" \
      >"$tmp_dir/newline-output.txt" 2>"$tmp_dir/newline-error.txt"
  ); then
    fail "newline-containing file path unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/newline-error.txt" "does not support file names containing newlines"
}

test_review_artifact_preparation_is_non_mutating() {
  local protected_repo="$tmp_dir/protected main review repo"
  local base_ref
  local artifact_env
  local status_before
  local worktrees_before
  local refs_before
  local exclude_file
  local exclude_before="$tmp_dir/protected-main-exclude-before"
  local exclude_existed=false

  mkdir -p "$protected_repo"
  git -C "$protected_repo" init -q
  git -C "$protected_repo" checkout -qb main
  git -C "$protected_repo" config user.name "Test User"
  git -C "$protected_repo" config user.email "test@example.com"
  printf '.tmp/\n' >"$protected_repo/.gitignore"
  printf 'base\n' >"$protected_repo/base.txt"
  git -C "$protected_repo" add .gitignore base.txt
  git -C "$protected_repo" commit -qm "chore: add protected review base"
  base_ref=$(git -C "$protected_repo" rev-parse HEAD)

  printf 'staged\n' >"$protected_repo/staged.txt"
  git -C "$protected_repo" add staged.txt
  printf 'unstaged\n' >>"$protected_repo/base.txt"
  printf 'untracked\n' >"$protected_repo/untracked.txt"

  status_before=$(git -C "$protected_repo" status --porcelain=v1 --untracked-files=all)
  worktrees_before=$(git -C "$protected_repo" worktree list --porcelain)
  refs_before=$(git -C "$protected_repo" for-each-ref --format='%(refname) %(objectname)')
  exclude_file=$(git -C "$protected_repo" rev-parse --git-path info/exclude)
  if [[ -e "$exclude_file" ]]; then
    cp "$exclude_file" "$exclude_before"
    exclude_existed=true
  fi

  artifact_env=$(
    cd "$protected_repo"
    /bin/bash "$prepare_script" "$base_ref" 2>"$tmp_dir/protected-main-prepare-error.txt"
  )
  [[ "$artifact_env" == "$protected_repo"/.tmp/my-pr/*/artifact.env ]] ||
    fail "protected review artifacts escaped the ignored .tmp/my-pr directory: $artifact_env"
  [[ -d "$(dirname "$artifact_env")" ]] || fail "protected review artifact directory was not created"
  git -C "$protected_repo" check-ignore -q -- .tmp/my-pr ||
    fail "protected review artifact directory is not ignored"

  [[ "$(git -C "$protected_repo" branch --show-current)" == "main" ]] ||
    fail "artifact preparation changed the protected branch"
  [[ "$(git -C "$protected_repo" status --porcelain=v1 --untracked-files=all)" == "$status_before" ]] ||
    fail "artifact preparation changed staged, unstaged, or untracked state"
  [[ "$(git -C "$protected_repo" worktree list --porcelain)" == "$worktrees_before" ]] ||
    fail "artifact preparation changed the worktree list"
  [[ "$(git -C "$protected_repo" for-each-ref --format='%(refname) %(objectname)')" == "$refs_before" ]] ||
    fail "artifact preparation changed repository refs"
  if [[ "$exclude_existed" == true ]]; then
    cmp -s "$exclude_before" "$exclude_file" ||
      fail "artifact preparation changed .git/info/exclude"
  else
    [[ ! -e "$exclude_file" ]] || fail "artifact preparation created .git/info/exclude"
  fi
}

assert_role_specific_dispatch_contract() {
  local overview="$skill_root/references/simplify/overview.md"
  local review_reference="$skill_root/references/review.md"
  local skill="$skill_root/SKILL.md"
  local native_role_launch
  local simplifier_dispatch
  local review_launch='- In Codex, spawn one `agent_type: reviewer` and one `agent_type: simplifier`, each with `fork_turns: "none"`. Do not set a model or reasoning-effort override.'
  local skill_review_launch='Codex host では agent_type: reviewer と agent_type: simplifier、fork_turns: "none" を使う。model と reasoning_effort は指定しない。'
  local apply_launch='Apply mode uses `simplifier_apply`. On Codex, `create` and `simplify` launch `agent_type: "simplifier_apply"` with `fork_turns: "none"`. Do not override `model` or `reasoning_effort` at spawn time; the role configuration supplies `gpt-5.6-terra` at `medium` effort.'

  native_role_launch=$(sed -n '/^## Native role launch$/,/^## Dispatch contract$/p' "$review_reference")
  [[ "$native_role_launch" == *"$review_launch"* ]] ||
    fail "Native role launch does not bind reviewer and simplifier to fork_turns none without overrides"
  assert_file_contains "$skill" "$skill_review_launch"
  assert_file_contains "$overview" "$apply_launch"
  simplifier_dispatch=$(sed -n '/^### Simplifier dispatch$/,/^## Integration rules$/p' "$review_reference")
  [[ "$simplifier_dispatch" == *$'Mode: review\n'* ]] ||
    fail "read-only simplifier dispatch does not declare Mode: review"
  [[ "$simplifier_dispatch" == *'Act as the read-only simplifier for the supplied PR artifact.'* ]] ||
    fail "read-only simplifier dispatch is missing its role-specific task"
}

assert_review_scope_gate_contract() {
  local review_reference="$skill_root/references/review.md"
  local review_base_gate
  local review_untracked_gate
  local default_fix_base_gate
  local default_fix_untracked_gate

  review_base_gate=$(sed -n '/^### `my-pr review`$/,/^### `default` and `fix`$/p' "$review_reference")
  review_untracked_gate=$(sed -n '/^For `my-pr review`:$/,/^For the default and `fix` workflows:$/p' "$review_reference")
  default_fix_base_gate=$(sed -n '/^### `default` and `fix`$/,/^The script prints one absolute `artifact.env` path\./p' "$review_reference")
  default_fix_untracked_gate=$(sed -n '/^For the default and `fix` workflows:$/,/^The state file persists these generated paths\./p' "$review_reference")
  [[ "$review_base_gate" == *'For `my-pr review`, resolve and verify an existing remote-tracking base ref without `git fetch`. Never mutate refs.'* ]] ||
    fail "my-pr review scope gate does not prohibit ref fetches"
  [[ "$review_base_gate" != *'git fetch origin '* ]] ||
    fail "my-pr review scope gate unexpectedly fetches the base ref"
  [[ "$review_untracked_gate" == *'`untracked` or `large+untracked`: stop and report the files without staging, `git add -N`, ignore or exclude changes, or file removal.'* ]] ||
    fail "my-pr review scope gate does not prohibit untracked-file mutations"
  [[ "$review_untracked_gate" != *'Stage or `git add -N` task-created files'* ]] ||
    fail "my-pr review scope gate unexpectedly permits staging untracked files"
  [[ "$default_fix_base_gate" == *'git fetch origin "+refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"'* ]] ||
    fail "default and fix scope gate is missing the safe remote-tracking fetch"
  [[ "$default_fix_untracked_gate" == *'Stage or `git add -N` task-created files that belong in the PR'* ]] ||
    fail "default and fix scope gate is missing permitted untracked-file resolution"
}

test_review_scope_gate_contract_rejects_regressions() {
  local fetch_regression_root="$tmp_dir/skill-with-review-fetch"
  local stage_regression_root="$tmp_dir/skill-with-review-staging"

  cp -R "$skill_root" "$fetch_regression_root"
  perl -0pi -e 's/without `git fetch`\. Never mutate refs\./with `git fetch`. Never mutate refs./' \
    "$fetch_regression_root/references/review.md"
  if (
    skill_root="$fetch_regression_root"
    assert_review_scope_gate_contract
  ) \
    >"$tmp_dir/review-fetch-contract.out" 2>&1; then
    fail "adding a review fetch unexpectedly passed the scope-gate contract"
  fi

  cp -R "$skill_root" "$stage_regression_root"
  perl -0pi -e 's/stop and report the files without staging, `git add -N`, ignore or exclude changes, or file removal/Stage or `git add -N` task-created files and regenerate artifacts/' \
    "$stage_regression_root/references/review.md"
  if (
    skill_root="$stage_regression_root"
    assert_review_scope_gate_contract
  ) \
    >"$tmp_dir/review-staging-contract.out" 2>&1; then
    fail "permitting review staging unexpectedly passed the scope-gate contract"
  fi
}

test_role_specific_dispatch_contract_rejects_regressions() {
  local missing_review_mode_root="$tmp_dir/skill-without-review-mode"
  local review_fork_all_root="$tmp_dir/skill-with-review-fork-all"

  cp -R "$skill_root" "$missing_review_mode_root"
  perl -0pi -e 's/^Mode: review$/Mode: inspect/m' \
    "$missing_review_mode_root/references/review.md"
  if (
    skill_root="$missing_review_mode_root"
    assert_role_specific_dispatch_contract
  ) \
    >"$tmp_dir/missing-review-mode-contract.out" 2>&1; then
    fail "removing the read-only simplifier Mode: review dispatch unexpectedly passed"
  fi

  cp -R "$skill_root" "$review_fork_all_root"
  perl -0pi -e 's/each with `fork_turns: "none"`\. Do not set a model or reasoning-effort override\./each with `fork_turns: "all"`. Do not set a model or reasoning-effort override./' \
    "$review_fork_all_root/references/review.md"
  if (
    skill_root="$review_fork_all_root"
    assert_role_specific_dispatch_contract
  ) \
    >"$tmp_dir/review-fork-all-contract.out" 2>&1; then
    fail "changing only the Native role launch review fork unexpectedly passed"
  fi
}

test_native_agent_contract() {
  local removed_source

  [[ -f "$reviewer_agent" ]] || fail "native reviewer agent is missing: $reviewer_agent"
  [[ -f "$simplifier_agent" ]] || fail "native simplifier agent is missing: $simplifier_agent"
  [[ -f "$simplifier_apply_agent" ]] || fail "native simplifier apply agent is missing: $simplifier_apply_agent"
  assert_file_contains "$reviewer_agent" 'name = "reviewer"'
  assert_file_contains "$reviewer_agent" 'model = "gpt-5.6-sol"'
  assert_file_contains "$reviewer_agent" 'model_reasoning_effort = "high"'
  assert_file_contains "$reviewer_agent" 'sandbox_mode = "read-only"'
  assert_file_contains "$reviewer_agent" 'Do not delegate, spawn subagents'
  assert_file_contains "$reviewer_agent" 'Never modify files, create patches, commit, push, deploy, apply configuration, or mutate external systems.'
  assert_file_line_count "$reviewer_agent" 'STATUS: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED' 1
  assert_file_line_count "$reviewer_agent" 'SUMMARY:' 1
  assert_file_line_count "$reviewer_agent" 'EVIDENCE:' 1
  assert_file_line_count "$reviewer_agent" 'CHECKS:' 1
  assert_file_line_count "$reviewer_agent" 'CONCERNS:' 1
  assert_file_contains "$simplifier_agent" 'name = "simplifier"'
  assert_file_contains "$simplifier_agent" 'model = "gpt-5.6-terra"'
  assert_file_contains "$simplifier_agent" 'model_reasoning_effort = "medium"'
  assert_file_contains "$simplifier_agent" 'sandbox_mode = "read-only"'
  assert_file_not_contains "$simplifier_agent" 'sandbox_mode = "workspace-write"'
  assert_file_contains "$simplifier_agent" 'Do not delegate, spawn subagents'
  assert_file_contains "$simplifier_agent" 'The prompt must state `Mode: review`.'
  assert_file_contains "$simplifier_agent" 'Never modify files, create patches, commit, push, deploy, apply configuration, or mutate external systems.'
  assert_file_contains "$simplifier_agent" 'inspect repository state beyond the exact supplied artifact and reference paths'
  assert_file_line_count "$simplifier_agent" 'STATUS: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED' 1
  assert_file_line_count "$simplifier_agent" 'SUMMARY:' 1
  assert_file_line_count "$simplifier_agent" 'EVIDENCE:' 1
  assert_file_line_count "$simplifier_agent" 'CHANGES:' 0
  assert_file_line_count "$simplifier_agent" 'CHECKS:' 1
  assert_file_line_count "$simplifier_agent" 'CONCERNS:' 1

  assert_file_contains "$simplifier_apply_agent" 'name = "simplifier_apply"'
  assert_file_contains "$simplifier_apply_agent" 'model = "gpt-5.6-terra"'
  assert_file_contains "$simplifier_apply_agent" 'model_reasoning_effort = "medium"'
  assert_file_contains "$simplifier_apply_agent" 'sandbox_mode = "workspace-write"'
  assert_file_contains "$simplifier_apply_agent" 'Do not delegate, spawn subagents'
  assert_file_contains "$simplifier_apply_agent" 'The prompt must state `Mode: apply` and provide explicit `Authorized write targets` and `Allowed read-only inputs`.'
  assert_file_contains "$simplifier_apply_agent" 'verify that `Authorized write targets` and `Allowed read-only inputs` are explicit and disjoint.'
  assert_file_contains "$simplifier_apply_agent" 'You may read both sets, but may edit only authorized write targets and allowed areas.'
  assert_file_contains "$simplifier_apply_agent" 'Never edit an allowed read-only input.'
  assert_file_contains "$simplifier_apply_agent" 'If a path appears in both sets, return BLOCKED and name the overlap.'
  assert_file_contains "$simplifier_apply_agent" 'Identify Required behavior-preserving simplifications within the authorized write targets and apply only those changes.'
  assert_file_contains "$simplifier_apply_agent" 'Do not commit, push, deploy, apply configuration, or mutate external systems.'
  assert_file_line_count "$simplifier_apply_agent" 'STATUS: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED' 1
  assert_file_line_count "$simplifier_apply_agent" 'SUMMARY:' 1
  assert_file_line_count "$simplifier_apply_agent" 'EVIDENCE:' 0
  assert_file_line_count "$simplifier_apply_agent" 'CHANGES:' 1
  assert_file_line_count "$simplifier_apply_agent" 'CHECKS:' 1
  assert_file_line_count "$simplifier_apply_agent" 'CONCERNS:' 1

  assert_file_contains "$skill_root/SKILL.md" '全 role・全 chunk の完了まで統合しない'
  assert_file_contains "$skill_root/SKILL.md" 'Review-only Safety gate'
  assert_file_contains "$skill_root/SKILL.md" 'worktree の移動・cleanup、reset、checkout、rm、stage / git add -N、commit、push、PR の変更を実行しない。'
  assert_file_contains "$skill_root/SKILL.md" '`review` で `untracked` または `large+untracked` なら、stage / git add -N や対象外化のための状態変更をせず停止して報告する。'
  assert_file_contains "$skill_root/references/commands.md" '`review` uses the Review-only Safety gate.'
  assert_file_contains "$skill_root/references/commands.md" 'must not invoke worktree transfer/cleanup, reset, checkout, rm, stage / git add -N, commit, push, PR mutation, or ref fetch.'
  assert_file_contains "$skill_root/references/commands.md" 'For default, `create`, `fix`, and `simplify`, the normal protected-branch worktree flow remains mandatory'
  assert_file_contains "$skill_root/references/branching.md" '## Review-only Safety gate'
  assert_file_contains "$skill_root/references/branching.md" 'do not transfer changes to a worktree or clean up the original worktree.'
  assert_file_contains "$skill_root/references/branching.md" 'Do not run reset, checkout, rm, stage / git add -N, commit, push, PR mutation, or ref fetch.'
  assert_file_contains "$skill_root/references/branching.md" 'Do not stage them, use `git add -N`, alter ignore or exclude metadata, or remove files to continue review.'
  assert_file_not_contains "$prepare_script" 'info/exclude'
  assert_file_contains "$skill_root/references/review.md" 'launch `reviewer` and `simplifier` concurrently'
  assert_file_contains "$skill_root/references/review.md" 'Do not integrate until all role results for all chunks have arrived.'
  assert_file_contains "$skill_root/references/review.md" 'stop without partial integration and return `REVIEW_INCOMPLETE`'
  assert_review_scope_gate_contract
  assert_file_contains "$skill_root/references/review.md" 'the `reviewer` may use read-only tools or bounded shell commands to inspect relevant unchanged callers'
  assert_file_contains "$skill_root/references/review.md" 'Mode: `review`, for the `simplifier` role only.'
  assert_file_contains "$skill_root/references/review.md" 'Mode: review'
  assert_file_contains "$skill_root/references/review.md" 'select matching rules from `Files covered`, or changed targets for a full diff'
  assert_file_contains "$skill_root/references/review.md" 'Provide the selected absolute paths in the documented order: TypeScript / JavaScript, Python, then Shell / Bash / Zsh.'
  assert_file_contains "$skill_root/references/review.md" 'none (no matching language-specific reference)'
  assert_file_contains "$skill_root/references/review.md" 'the `simplifier` may read only the exact supplied simplifier overview, PR-context, diff or chunk, and language-reference paths.'
  assert_file_contains "$skill_root/references/review.md" 'overview, PR context, diff or chunk, then each supplied language reference in the documented order.'
  assert_file_contains "$skill_root/references/simplify/overview.md" 'apply only Required, behavior-preserving simplifications'
  assert_file_contains "$skill_root/references/simplify/overview.md" 'The main workflow owns final diff review, project verification, and any commit.'
  assert_role_specific_dispatch_contract
  assert_file_contains "$skill_root/references/simplify/overview.md" 'On Claude Code, use native Agents for review and apply'
  assert_file_contains "$skill_root/references/simplify/overview.md" 'The absolute `references/simplify/overview.md` path.'
  assert_file_contains "$skill_root/references/simplify/overview.md" 'Select language-specific rules from `Files covered`, or from changed targets for a full diff'
  assert_file_contains "$skill_root/references/simplify/overview.md" '`references/simplify/shell.md`'
  assert_file_contains "$skill_root/references/simplify/overview.md" '`Authorized write targets`: only requested product files and allowed areas that the subagent may edit.'
  assert_file_contains "$skill_root/references/simplify/overview.md" '`Allowed read-only inputs`: the common overview, task context, and applicable language rules'
  assert_file_contains "$skill_root/references/simplify/overview.md" 'Rules can be read without becoming writable.'
  assert_file_contains "$skill_root/references/simplify/overview.md" 'If either set is missing or ambiguous, return `NEEDS_CONTEXT`. If the sets overlap, or the request requires editing an allowed read-only input, return `BLOCKED`.'
  assert_file_contains "$skill_root/references/simplify/overview.md" 'Authorized write targets: <apply mode: explicit product paths and allowed areas; review mode: none>'
  assert_file_contains "$skill_root/references/simplify/overview.md" 'Allowed read-only inputs: <absolute common overview, task context, applicable language-rule paths, and review artifacts; none only when no input exists>'
  assert_file_contains "$skill_root/references/simplify/overview.md" '<MATCHING_ABSOLUTE_LANGUAGE_REFERENCES_IN_DOCUMENTED_ORDER_OR_NONE>'
  assert_file_contains "$skill_root/references/simplify/overview.md" 'Read the supplied `references/simplify/overview.md` path, then the PR context, then the diff or chunk, then each supplied language-reference path in the documented order.'

  for removed_source in \
    "$skill_root/scripts/executable_run-codex-review.sh" \
    "$skill_root/scripts/executable_run-codex-reviews.sh" \
    "$skill_root/scripts/executable_validate-reviewer-b-output.sh" \
    "$skill_root/assets/codex-review-result.schema.json" \
    "$skill_root/assets/claude-review-result.schema.json"; do
    [[ ! -e "$removed_source" ]] || fail "removed my-pr source still exists: $removed_source"
  done

  assert_skill_tree_not_matching 'claude[[:space:]]+(-p|--[[:alnum:]-]+)' "a Claude CLI command"
  assert_skill_tree_not_matching 'codex[[:space:]]+exec' "a Codex executor command"
  assert_skill_tree_not_matching 'run-codex-review' "a removed Codex runner"
  assert_skill_tree_not_matching 'codex-review-result\.schema\.json' "a removed Codex schema"
  assert_skill_tree_not_matching 'claude-review-result\.schema\.json' "a removed Claude schema"
  assert_skill_tree_not_matching 'Reviewer[[:space:]]+[ABC]' "a legacy Reviewer A/B/C reference"
}

test_documented_state_contract() {
  if grep -R -n -- 'MY_PR_SKILL_DIR' "$skill_root" >"$tmp_dir/legacy-skill-dir.txt"; then
    cat "$tmp_dir/legacy-skill-dir.txt" >&2
    fail "my-pr still depends on MY_PR_SKILL_DIR"
  fi
  if grep -R -n -- 'eval "$(bash' "$skill_root" >"$tmp_dir/legacy-eval.txt"; then
    cat "$tmp_dir/legacy-eval.txt" >&2
    fail "my-pr still documents cross-shell eval state"
  fi
}

test_chunking
test_review_artifact_preparation_is_non_mutating
test_native_agent_contract
test_role_specific_dispatch_contract_rejects_regressions
test_review_scope_gate_contract_rejects_regressions
test_documented_state_contract
echo "PASS: my-pr review input tests"
