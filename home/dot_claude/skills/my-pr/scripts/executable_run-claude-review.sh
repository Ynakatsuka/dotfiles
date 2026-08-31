#!/usr/bin/env bash
set -euo pipefail

usage='Usage: run-claude-review.sh <chunk-id> <chunk-count> <prompt-file> <context-file> <diff-file>'
if (($# != 5)); then
  echo "ERROR: $usage" >&2
  exit 1
fi

chunk_id=$1
chunk_count=$2
prompt_file=$3
context_file=$4
diff_file=$5

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
resolve_script() {
  local script_name=$1
  local source_path="$script_dir/executable_${script_name}"
  local deployed_path="$script_dir/$script_name"

  if [[ -f "$source_path" && ! -e "$deployed_path" ]]; then
    printf '%s\n' "$source_path"
    return
  fi
  if [[ -f "$deployed_path" && ! -e "$source_path" ]]; then
    printf '%s\n' "$deployed_path"
    return
  fi
  echo "ERROR: expected exactly one script path: $source_path or $deployed_path" >&2
  return 1
}

prepare_input=$(resolve_script prepare-reviewer-b-input.sh)
schema_file="$script_dir/../assets/claude-review-result.schema.json"
for required_file in "$prepare_input" "$schema_file"; do
  if [[ ! -f "$required_file" ]]; then
    echo "ERROR: Reviewer B dependency not found: $required_file" >&2
    exit 1
  fi
done

input_prompt=$(bash "$prepare_input" "$chunk_id" "$chunk_count" "$prompt_file" "$context_file" "$diff_file")
result_dir=$(dirname "$input_prompt")
result_event="$result_dir/result-event.json"
review_markdown="$result_dir/review.md"
stdout_log="$result_dir/stdout.log"
stderr_log="$result_dir/stderr.log"
isolated_cwd="$result_dir/claude-cwd"
rm -f "$result_event" "$review_markdown" "$stdout_log" "$stderr_log"
rm -rf "$isolated_cwd"
mkdir -p "$isolated_cwd"
git -C "$isolated_cwd" init -q

claude_bin=${MY_PR_CLAUDE_BIN:-claude}
claude_args=(
  -p
  --model opus
  --effort high
  --permission-mode plan
  --tools ""
  --safe-mode
  --no-chrome
  --disable-slash-commands
  --strict-mcp-config
  --mcp-config '{"mcpServers":{}}'
  --output-format stream-json
  --verbose
  --json-schema "$(jq -c . "$schema_file")"
)

if ! (
  cd "$isolated_cwd"
  CLAUDE_CODE_EFFORT_LEVEL=high "$claude_bin" "${claude_args[@]}" <"$input_prompt"
) >"$stdout_log" 2>"$stderr_log"; then
  echo "ERROR: Claude reviewer failed: chunk=$chunk_id stdout=$stdout_log stderr=$stderr_log" >&2
  exit 1
fi

if ! jq -s -e '
  [ .[] | select(.type == "result") ] as $results |
  ($results | length) == 1 and
  $results[0].is_error == false and
  (($results[0].permission_denials // []) | length) == 0 and
  ($results[0].structured_output.review_markdown | type == "string" and length > 0)
' "$stdout_log" >/dev/null; then
  echo "ERROR: Claude reviewer final result is missing, incomplete, or denied: $stdout_log" >&2
  exit 1
fi

jq -s '[ .[] | select(.type == "result") ][0]' "$stdout_log" >"$result_event"
jq -r '.structured_output.review_markdown' "$result_event" >"$review_markdown"

printf '%s\n' "$review_markdown"
