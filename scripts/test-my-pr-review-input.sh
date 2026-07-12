#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
split_script="$repo_root/home/dot_claude/skills/my-pr/scripts/executable_split-review-chunks.sh"
runner_script="$repo_root/home/dot_claude/skills/my-pr/scripts/executable_run-codex-review.sh"
prepare_script="$repo_root/home/dot_claude/skills/my-pr/scripts/executable_prepare-review-artifacts.sh"
reviewer_b_validator="$repo_root/home/dot_claude/skills/my-pr/scripts/executable_validate-reviewer-b-output.sh"
reviewer_b_schema="$repo_root/home/dot_claude/skills/my-pr/assets/claude-review-result.schema.json"

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

test_chunking() {
  local test_repo="$tmp_dir/repo with space"
  local artifact_dir
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

  (
    cd "$test_repo"
    eval "$(/bin/bash "$prepare_script" "$base_ref" 2>"$tmp_dir/prepare-error.txt")"
    printf '%s\n' "$MY_PR_ARTIFACT_DIR" >"$tmp_dir/artifact-path.txt"
    printf '%s\n' "$MY_PR_REVIEW_BYTES" >"$tmp_dir/review-bytes.txt"
  )
  artifact_dir="$test_repo/$(cat "$tmp_dir/artifact-path.txt")"
  [[ "$(cat "$tmp_dir/review-bytes.txt")" =~ ^[1-9][0-9]*$ ]] || fail "review byte count was not exported"
  assert_file_contains "$artifact_dir/changed-files.txt" "src/日本語.txt"

  (
    cd "$test_repo"
    MY_PR_ARTIFACT_DIR="$artifact_dir" \
      MY_PR_REVIEW_CHUNK_MAX_BYTES=20000 \
      /bin/bash "$split_script" "$base_ref" >"$tmp_dir/chunk-output.txt"
  )

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
    MY_PR_ARTIFACT_DIR="$artifact_dir" \
      MY_PR_REVIEW_CHUNK_MAX_BYTES=196609 \
      /bin/bash "$split_script" "$base_ref" \
      >"$tmp_dir/raised-chunk-cap-output.txt" 2>"$tmp_dir/raised-chunk-cap-error.txt"
  ); then
    fail "raised chunk cap unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/raised-chunk-cap-error.txt" "8193 through 196608"

  awk 'BEGIN { for (i = 1; i <= 11000; i++) print "+0123456789" }' >"$test_repo/docs/oversized.md"
  git -C "$test_repo" add docs/oversized.md
  git -C "$test_repo" commit -qm "test: add oversized review fixture"
  local oversized_artifact
  (
    cd "$test_repo"
    eval "$(/bin/bash "$prepare_script" "$base_ref" 2>"$tmp_dir/oversized-prepare-error.txt")"
    printf '%s\n' "$MY_PR_ARTIFACT_DIR" >"$tmp_dir/oversized-artifact-path.txt"
  )
  oversized_artifact="$test_repo/$(cat "$tmp_dir/oversized-artifact-path.txt")"
  (
    cd "$test_repo"
    MY_PR_ARTIFACT_DIR="$oversized_artifact" \
      /bin/bash "$split_script" "$base_ref" \
      >"$tmp_dir/oversized-file-output.txt" 2>"$tmp_dir/oversized-file-error.txt"
  )
  assert_file_contains "$oversized_artifact/chunks/all-covered.txt" "docs/oversized.md"
  [[ ! -s "$oversized_artifact/chunks/skipped-files.txt" ]] ||
    fail "a file below the raised default limit was skipped"

  awk 'BEGIN { for (i = 1; i <= 22000; i++) print "+0123456789" }' >"$test_repo/docs/too-large.json"
  git -C "$test_repo" add docs/too-large.json
  git -C "$test_repo" commit -qm "test: add skipped review fixture"
  local skipped_artifact
  (
    cd "$test_repo"
    eval "$(/bin/bash "$prepare_script" "$base_ref" 2>"$tmp_dir/skipped-prepare-error.txt")"
    printf '%s\n' "$MY_PR_ARTIFACT_DIR" >"$tmp_dir/skipped-artifact-path.txt"
  )
  skipped_artifact="$test_repo/$(cat "$tmp_dir/skipped-artifact-path.txt")"
  (
    cd "$test_repo"
    MY_PR_ARTIFACT_DIR="$skipped_artifact" \
      /bin/bash "$split_script" "$base_ref" \
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
  (
    cd "$skipped_only_repo"
    eval "$(/bin/bash "$prepare_script" "$skipped_only_base" 2>"$tmp_dir/skipped-only-prepare-error.txt")"
    printf '%s\n' "$MY_PR_ARTIFACT_DIR" >"$tmp_dir/skipped-only-artifact-path.txt"
  )
  skipped_only_artifact="$skipped_only_repo/$(cat "$tmp_dir/skipped-only-artifact-path.txt")"
  (
    cd "$skipped_only_repo"
    MY_PR_ARTIFACT_DIR="$skipped_only_artifact" \
      /bin/bash "$split_script" "$skipped_only_base" \
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

write_fake_codex() {
  local fake="$tmp_dir/fake-codex"
  cat >"$fake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output_file=
printf '%s\n' "$@" >"${FAKE_ARGS:?}"
while (($# > 0)); do
  case "$1" in
    -o)
      output_file=$2
      shift 2
      ;;
    --output-schema|-c|--sandbox)
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[[ -n "$output_file" ]]
if [[ "${FAKE_IGNORE_TAIL:-0}" == "1" ]]; then
  head -n 25 >"${FAKE_CAPTURE:?}"
else
  cat >"${FAKE_CAPTURE:?}"
fi
if [[ -n "${FAKE_EXIT_CODE:-}" ]]; then
  exit "$FAKE_EXIT_CODE"
fi
if [[ "${FAKE_NO_RESULT:-0}" == "1" ]]; then
  exit 0
fi

receipt=$(grep '^MY_PR_END_RECEIPT ' "$FAKE_CAPTURE" | tail -n 1 || true)
reviewer=${receipt#* reviewer=}
reviewer=${reviewer%% *}
chunk_id=${receipt#* chunk_id=}
chunk_id=${chunk_id%% *}
chunk_count=${receipt#* chunk_count=}
chunk_count=${chunk_count%% *}
context_sha=${receipt#* context_sha256=}
context_sha=${context_sha%% *}
diff_sha=${receipt#* diff_sha256=}
diff_sha=${diff_sha%% *}
end_nonce=${receipt#* end_nonce=}
end_nonce=${end_nonce%% *}
if [[ "${FAKE_BAD_RECEIPT:-0}" == "1" ]]; then
  diff_sha=0000000000000000000000000000000000000000000000000000000000000000
fi

if [[ "${FAKE_SHORT_MARKDOWN:-0}" == "1" ]]; then
  review_markdown='# Review'
elif [[ "$reviewer" == "A" ]]; then
  review_markdown='# Simplify Review

## Required
- none

## Recommended
- none

## Not needed
- none'
else
  review_markdown='## PR understanding
- complete

## Strengths
- none

## Findings
- none

## Non-findings
- none

## Assessment

**Ready to merge?** Yes'
fi

jq -n \
  --arg reviewer "$reviewer" \
  --arg chunk_id "$chunk_id" \
  --argjson chunk_count "$chunk_count" \
  --arg context_sha "$context_sha" \
  --arg diff_sha "$diff_sha" \
  --arg end_nonce "$end_nonce" \
  --arg status "${FAKE_STATUS:-COMPLETE}" \
  --arg review_markdown "$review_markdown" \
  '{
    status: $status,
    reviewer: $reviewer,
    chunk_id: $chunk_id,
    chunk_count: $chunk_count,
    context_sha256: $context_sha,
    diff_sha256: $diff_sha,
    end_nonce: $end_nonce,
    saw_context_end: true,
    saw_diff_end: true,
    review_markdown: $review_markdown
  }' >"$output_file"
EOF
  chmod +x "$fake"
  printf '%s\n' "$fake"
}

test_runner() {
  local artifact_dir="$tmp_dir/runner artifacts"
  local prompt_file="$artifact_dir/reviewer-prompt.md"
  local context_file="$artifact_dir/pr-context.md"
  local diff_file="$artifact_dir/review.diff"
  local fake_codex

  mkdir -p "$artifact_dir"
  printf 'Review the supplied input and report findings.\n' >"$prompt_file"
  awk 'BEGIN { for (i = 1; i <= 300; i++) print "context line " i " 日本語" }' >"$context_file"
  awk 'BEGIN { for (i = 1; i <= 500; i++) print "+diff line " i " abcdefghijklmnopqrstuvwxyz" }' >"$diff_file"
  fake_codex=$(write_fake_codex)

  MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_ARGS="$tmp_dir/reviewer-a-args.txt" \
    FAKE_CAPTURE="$tmp_dir/reviewer-a-input.md" \
    /bin/bash "$runner_script" reviewer-a full 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/reviewer-a-output.txt"

  assert_file_contains "$tmp_dir/reviewer-a-args.txt" "multi_agent"
  assert_file_contains "$tmp_dir/reviewer-a-args.txt" "hooks"
  assert_file_contains "$tmp_dir/reviewer-a-args.txt" "plugins"
  assert_file_contains "$tmp_dir/reviewer-a-args.txt" "remote_plugin"
  assert_file_contains "$tmp_dir/reviewer-a-args.txt" "mcp_servers={}"
  assert_file_contains "$tmp_dir/reviewer-a-args.txt" 'model_reasoning_effort="medium"'
  assert_file_contains "$tmp_dir/reviewer-a-input.md" "context line 300 日本語"
  assert_file_contains "$tmp_dir/reviewer-a-input.md" "+diff line 500 abcdefghijklmnopqrstuvwxyz"
  assert_file_contains "$artifact_dir/reviewer-results/reviewer-a/full/review.md" "# Simplify Review"
  eval "$(cat "$tmp_dir/reviewer-a-output.txt")"
  [[ -f "$MY_PR_CODEX_REVIEW_MARKDOWN" ]] || fail "escaped runner output is not sourceable"

  MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_ARGS="$tmp_dir/reviewer-c-args.txt" \
    FAKE_CAPTURE="$tmp_dir/reviewer-c-input.md" \
    /bin/bash "$runner_script" reviewer-c full 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/reviewer-c-output.txt"
  if grep -Fq 'model_reasoning_effort' "$tmp_dir/reviewer-c-args.txt"; then
    fail "Reviewer C must preserve the global reasoning effort"
  fi

  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    MY_PR_CODEX_PROMPT_MAX_BYTES=100 \
    FAKE_ARGS="$tmp_dir/oversized-args.txt" \
    FAKE_CAPTURE="$tmp_dir/oversized-input.md" \
    /bin/bash "$runner_script" reviewer-c oversized 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/oversized-output.txt" 2>"$tmp_dir/oversized-error.txt"; then
    fail "oversized prompt unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/oversized-error.txt" "prompt exceeds byte limit"

  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    MY_PR_CODEX_PROMPT_MAX_BYTES=393217 \
    FAKE_ARGS="$tmp_dir/raised-cap-args.txt" \
    FAKE_CAPTURE="$tmp_dir/raised-cap-input.md" \
    /bin/bash "$runner_script" reviewer-c raised-cap 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/raised-cap-output.txt" 2>"$tmp_dir/raised-cap-error.txt"; then
    fail "raised prompt cap unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/raised-cap-error.txt" "1 through 393216"

  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_BAD_RECEIPT=1 \
    FAKE_ARGS="$tmp_dir/bad-receipt-args.txt" \
    FAKE_CAPTURE="$tmp_dir/bad-receipt-input.md" \
    /bin/bash "$runner_script" reviewer-c bad-receipt 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/bad-receipt-output.txt" 2>"$tmp_dir/bad-receipt-error.txt"; then
    fail "bad receipt unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/bad-receipt-error.txt" "receipt or status is invalid"

  mkdir -p "$artifact_dir/reviewer-results/reviewer-c/stale"
  cp "$artifact_dir/reviewer-results/reviewer-c/full/result.json" \
    "$artifact_dir/reviewer-results/reviewer-c/stale/result.json"
  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_NO_RESULT=1 \
    FAKE_ARGS="$tmp_dir/stale-args.txt" \
    FAKE_CAPTURE="$tmp_dir/stale-input.md" \
    /bin/bash "$runner_script" reviewer-c stale 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/stale-output.txt" 2>"$tmp_dir/stale-error.txt"; then
    fail "stale result unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/stale-error.txt" "result is missing or empty"

  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_EXIT_CODE=7 \
    FAKE_ARGS="$tmp_dir/nonzero-args.txt" \
    FAKE_CAPTURE="$tmp_dir/nonzero-input.md" \
    /bin/bash "$runner_script" reviewer-c nonzero 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/nonzero-output.txt" 2>"$tmp_dir/nonzero-error.txt"; then
    fail "non-zero Codex exit unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/nonzero-error.txt" "Codex reviewer failed"

  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_STATUS=REVIEW_INCOMPLETE \
    FAKE_ARGS="$tmp_dir/incomplete-args.txt" \
    FAKE_CAPTURE="$tmp_dir/incomplete-input.md" \
    /bin/bash "$runner_script" reviewer-c incomplete 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/incomplete-output.txt" 2>"$tmp_dir/incomplete-error.txt"; then
    fail "incomplete reviewer status unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/incomplete-error.txt" "receipt or status is invalid"

  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_ARGS="$tmp_dir/missing-args.txt" \
    FAKE_CAPTURE="$tmp_dir/missing-input.md" \
    /bin/bash "$runner_script" reviewer-c missing 1 "$prompt_file" "$context_file.missing" "$diff_file" \
    >"$tmp_dir/missing-output.txt" 2>"$tmp_dir/missing-error.txt"; then
    fail "missing review input unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/missing-error.txt" "review input not found"

  : >"$artifact_dir/empty.md"
  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_ARGS="$tmp_dir/empty-args.txt" \
    FAKE_CAPTURE="$tmp_dir/empty-input.md" \
    /bin/bash "$runner_script" reviewer-c empty 1 "$prompt_file" "$artifact_dir/empty.md" "$diff_file" \
    >"$tmp_dir/empty-output.txt" 2>"$tmp_dir/empty-error.txt"; then
    fail "empty review input unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/empty-error.txt" "not found or empty"

  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_IGNORE_TAIL=1 \
    FAKE_ARGS="$tmp_dir/no-tail-args.txt" \
    FAKE_CAPTURE="$tmp_dir/no-tail-input.md" \
    /bin/bash "$runner_script" reviewer-c no-tail 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/no-tail-output.txt" 2>"$tmp_dir/no-tail-error.txt"; then
    fail "reviewer without end receipt unexpectedly succeeded"
  fi

  if MY_PR_ARTIFACT_DIR="$artifact_dir" \
    MY_PR_CODEX_BIN="$fake_codex" \
    FAKE_SHORT_MARKDOWN=1 \
    FAKE_ARGS="$tmp_dir/short-markdown-args.txt" \
    FAKE_CAPTURE="$tmp_dir/short-markdown-input.md" \
    /bin/bash "$runner_script" reviewer-c short-markdown 1 "$prompt_file" "$context_file" "$diff_file" \
    >"$tmp_dir/short-markdown-output.txt" 2>"$tmp_dir/short-markdown-error.txt"; then
    fail "incomplete review Markdown unexpectedly succeeded"
  fi
  assert_file_contains "$tmp_dir/short-markdown-error.txt" "missing required section"
}

test_reviewer_b_validator() {
  local valid="$tmp_dir/reviewer-b-valid.md"
  local summary="$tmp_dir/reviewer-b-summary.md"

  cat >"$valid" <<'EOF'
## PR understanding
- Description: test

## Strengths
- none

## Findings
- none

## Non-findings
- none

## Assessment

**Ready to merge?** Yes

**Reasoning:** No findings.
EOF
  printf '%s\n' 'Reviewer B completed the review and found no blocking issues.' >"$summary"

  /bin/bash "$reviewer_b_validator" "$valid"
  if /bin/bash "$reviewer_b_validator" "$summary" \
    >"$tmp_dir/reviewer-b-summary-output.txt" 2>"$tmp_dir/reviewer-b-summary-error.txt"; then
    fail "Reviewer B summary unexpectedly passed validation"
  fi
  assert_file_contains "$tmp_dir/reviewer-b-summary-error.txt" "missing required section"
}

test_reviewer_b_schema() {
  jq -e '
    has("$schema") | not
  ' "$reviewer_b_schema" >/dev/null ||
    fail "Reviewer B schema must not declare a dialect unsupported by Claude CLI"

  jq -e '
    .type == "object" and
    .additionalProperties == false and
    .required == ["review_markdown"] and
    .properties.review_markdown.type == "string"
  ' "$reviewer_b_schema" >/dev/null ||
    fail "Reviewer B schema does not require review_markdown"
}

test_chunking
test_runner
test_reviewer_b_validator
test_reviewer_b_schema
echo "PASS: my-pr review input tests"
