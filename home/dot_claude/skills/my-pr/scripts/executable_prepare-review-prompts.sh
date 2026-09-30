#!/usr/bin/env bash
set -euo pipefail

# Renders the fixed reviewer role prompts from assets/review-prompts/ so the
# orchestrator never retypes them. Reviewer B and Reviewer C share the
# correctness prompt; Reviewer A uses the simplify prompt.

usage='Usage: prepare-review-prompts.sh <artifact-env-file> [additional-focus-file]'
if (($# < 1 || $# > 2)); then
  echo "ERROR: $usage" >&2
  exit 1
fi

artifact_env=$1
focus_file=${2:-}
if [[ ! -f "$artifact_env" ]]; then
  echo "ERROR: artifact state file not found: $artifact_env" >&2
  exit 1
fi
if [[ -n "$focus_file" && ! -s "$focus_file" ]]; then
  echo "ERROR: additional focus file not found or empty: $focus_file" >&2
  exit 1
fi
artifact_env=$(cd "$(dirname "$artifact_env")" && pwd -P)/$(basename "$artifact_env")
# shellcheck source=/dev/null
source "$artifact_env"
: "${MY_PR_ARTIFACT_DIR:?Invalid artifact state: MY_PR_ARTIFACT_DIR is missing}"
: "${MY_PR_ARTIFACT_ENV:?Invalid artifact state: MY_PR_ARTIFACT_ENV is missing}"
: "${MY_PR_BASE_REF:?Invalid artifact state: MY_PR_BASE_REF is missing}"
: "${MY_PR_CHANGED_FILES:?Invalid artifact state: MY_PR_CHANGED_FILES is missing}"
if [[ "$MY_PR_ARTIFACT_ENV" != "$artifact_env" ]]; then
  echo "ERROR: artifact state path mismatch: expected=$artifact_env actual=$MY_PR_ARTIFACT_ENV" >&2
  exit 1
fi
if [[ ! -f "$MY_PR_CHANGED_FILES" ]]; then
  echo "ERROR: changed files list not found: $MY_PR_CHANGED_FILES" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
template_dir="$script_dir/../assets/review-prompts"

repo_root=$(git rev-parse --show-toplevel)
# The branch comes from the current checkout, so it must be the checkout that
# owns this repo-local artifact.
if [[ "$MY_PR_ARTIFACT_DIR" != "$repo_root"/* ]]; then
  echo "ERROR: artifact dir is outside the current repository: artifact=$MY_PR_ARTIFACT_DIR repo=$repo_root" >&2
  exit 1
fi
branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)

# Unique names keep a caller-supplied focus file from colliding with these
# intermediate files.
context_block=$(mktemp "$MY_PR_ARTIFACT_DIR/review-prompt-context.XXXXXX")
focus_block=$(mktemp "$MY_PR_ARTIFACT_DIR/review-prompt-focus.XXXXXX")
trap 'rm -f "$context_block" "$focus_block"' EXIT
{
  printf '<context>\n'
  printf 'Branch: %s\n' "$branch"
  printf 'Base branch: %s\n' "${MY_PR_BASE_REF#origin/}"
  printf 'Base ref: %s\n' "$MY_PR_BASE_REF"
  printf 'Changed files:\n'
  cat "$MY_PR_CHANGED_FILES"
  printf 'The complete PR context and review diff are embedded after these instructions.\n'
  printf '</context>\n'
} >"$context_block"

if [[ -n "$focus_file" ]]; then
  {
    printf '<additional_focus>\n'
    cat "$focus_file"
    printf '</additional_focus>\n'
  } >"$focus_block"
fi

render_prompt() {
  local template=$1
  local output=$2
  local placeholder

  if [[ ! -f "$template" ]]; then
    echo "ERROR: review prompt template not found: $template" >&2
    exit 1
  fi
  for placeholder in '{{REVIEW_CONTEXT}}' '{{ADDITIONAL_FOCUS}}'; do
    if [[ "$(grep -cxF -- "$placeholder" "$template")" != 1 ]]; then
      echo "ERROR: template must contain $placeholder exactly once on its own line: $template" >&2
      exit 1
    fi
  done
  # Paths go through ENVIRON because awk -v would interpret backslashes.
  MY_PR_CONTEXT_BLOCK="$context_block" MY_PR_FOCUS_BLOCK="$focus_block" awk '
    function emit(file,    line, status) {
      while ((status = (getline line < file)) > 0) print line
      if (status < 0) {
        print "ERROR: cannot read prompt block: " file > "/dev/stderr"
        exit 1
      }
      close(file)
    }
    $0 == "{{REVIEW_CONTEXT}}" { emit(ENVIRON["MY_PR_CONTEXT_BLOCK"]); next }
    $0 == "{{ADDITIONAL_FOCUS}}" { emit(ENVIRON["MY_PR_FOCUS_BLOCK"]); next }
    { print }
  ' "$template" >"$output"
}

simplify_prompt="$MY_PR_ARTIFACT_DIR/simplify-review-prompt.md"
correctness_prompt="$MY_PR_ARTIFACT_DIR/correctness-review-prompt.md"
render_prompt "$template_dir/simplify.md" "$simplify_prompt"
render_prompt "$template_dir/correctness.md" "$correctness_prompt"

{
  printf 'export MY_PR_SIMPLIFY_PROMPT=%q\n' "$simplify_prompt"
  printf 'export MY_PR_CORRECTNESS_PROMPT=%q\n' "$correctness_prompt"
} >>"$artifact_env"
latest_env="$(dirname "$MY_PR_ARTIFACT_DIR")/latest-env.sh"
if [[ -f "$latest_env" ]]; then
  cp "$artifact_env" "$latest_env"
fi

printf 'simplify\t%s\n' "$simplify_prompt"
printf 'correctness\t%s\n' "$correctness_prompt"
