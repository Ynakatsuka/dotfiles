# Shared branch naming for gwai-cmux and gwai-orca.

validate_branch_name() {
  local branch_name="$1"

  [[ "$branch_name" =~ ^(feat|fix|refactor|docs|test|chore|perf)-[a-z0-9][a-z0-9-]*$ ]] ||
    die "branch name is invalid: $branch_name"
}

generate_branch_name() {
  local prompt="$1"
  local model="$2"
  local naming_prompt naming_output branch_type branch_slug branch_name field_count

  naming_prompt="Generate exactly one git branch type and slug for the task below.
Rules:
- Output exactly two tokens separated by one space: <type> <slug>
- <type> must be one of: feat, fix, refactor, docs, test, chore, perf
- <slug> must be kebab-case, ASCII only, 3-7 words.
- Do not include the type in <slug>. The shell function prefixes it.
- Output ONLY the two tokens. No quotes, no commentary, no trailing punctuation.

Task: ${prompt}"

  naming_output=$(claude -p --model "$model" "$naming_prompt" 2>/dev/null |
    tr -d '\r`"' |
    sed -E "s/'//g; s/^[[:space:]]+|[[:space:]]+$//g" |
    awk 'NF { print; exit }') ||
    die "branch name generation failed"

  [[ -n "$naming_output" ]] ||
    die "branch name generation returned empty output"

  field_count=$(printf '%s\n' "$naming_output" | awk '{ print NF }')
  [[ "$field_count" == "2" ]] ||
    die "branch name generation returned invalid output: $naming_output"

  branch_type=${naming_output%% *}
  branch_slug=${naming_output#* }

  [[ "$branch_type" =~ ^(feat|fix|refactor|docs|test|chore|perf)$ ]] ||
    die "generated branch type is invalid: $branch_type"
  [[ "$branch_slug" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
    die "generated branch slug is invalid: $branch_slug"

  branch_name="${branch_type}-${branch_slug}"
  validate_branch_name "$branch_name"

  printf '%s\n' "$branch_name"
}
