# Shared Codex invocation for the bulk reader and code writer. Source this
# file from the deployed ~/.local/bin commands.

delegation_codex_exec() {
  local command_name=$1 model=$2 reasoning_effort=$3 sandbox=$4
  local prompt_file=$5 answer_file=$6 codex_log=$7 status=0

  # codex exec echoes prompts and edits to its output streams. Keep them out
  # of the caller's context and surface only errors.
  codex exec \
    --model "$model" \
    -c "model_reasoning_effort=\"${reasoning_effort}\"" \
    -c 'approval_policy="never"' \
    --sandbox "$sandbox" \
    --ephemeral \
    --skip-git-repo-check \
    --disable hooks \
    --disable multi_agent \
    --color never \
    --output-last-message "$answer_file" \
    - <"$prompt_file" >"$codex_log" 2>&1 || status=$?
  if [[ "$status" -ne 0 ]]; then
    echo "$command_name: codex exec failed with exit code ${status}" >&2
    grep -E '^(ERROR|error)' "$codex_log" >&2 || tail -n 20 "$codex_log" >&2
    return "$status"
  fi
}
