#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' 'Usage: launch-orca-handoff.sh --name <topic> --agent codex|claude [--tab] [--base-branch <ref>] < brief'
}

stage=arguments
destination=''
terminal=''
task_name=''
agent=''
mode=worktree
base_ref=''
scratch=''

fail() {
  printf 'ERROR [%s]: %s\n' "$stage" "$1" >&2
  [[ -z "$task_name" ]] || printf 'name=%s\n' "$task_name" >&2
  [[ -z "$destination" ]] || printf 'worktree=%s\n' "$destination" >&2
  [[ -z "$terminal" ]] || printf 'terminal=%s\n' "$terminal" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --name | --agent | --base-branch)
      (($# >= 2)) && [[ -n "$2" ]] || fail "missing value for $1"
      case "$1" in
        --name) task_name=$2 ;;
        --agent) agent=$2 ;;
        --base-branch) base_ref=$2 ;;
      esac
      shift 2
      ;;
    --tab)
      mode=tab
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ "$task_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9._/-]*$ ]] || fail '--name must be a short branch-safe topic name'
[[ "$agent" == codex || "$agent" == claude ]] || fail '--agent must be codex or claude'
[[ "$mode" != tab || -z "$base_ref" ]] || fail '--tab cannot use --base-branch'
for executable in git jq mktemp; do
  command -v "$executable" >/dev/null 2>&1 || fail "required executable missing: $executable"
done
git check-ref-format --branch "$task_name" >/dev/null || fail 'invalid branch name'

# A caller may select a supported Orca executable, never a shell command string.
orca_cli=${ORCA_CLI_COMMAND:-orca}
command -v "$orca_cli" >/dev/null 2>&1 || fail "Orca CLI missing: $orca_cli"
[[ -z "${ORCA_ENVIRONMENT:-}" && -z "${ORCA_PAIRING_CODE:-}" ]] || fail 'this helper requires the local Orca runtime'
[[ ! -t 0 ]] || fail 'supply a handoff brief on standard input'
brief=$(</dev/stdin)
[[ "$brief" =~ [^[:space:]] ]] || fail 'handoff brief is empty'

stage=source
repo_root=$(git rev-parse --show-toplevel) || fail 'run inside the source Git worktree'
cd "$repo_root"
if [[ -n "$base_ref" ]]; then
  base_sha=$(git rev-parse --verify --end-of-options "${base_ref}^{commit}") || fail 'base ref is not a local commit'
  if [[ "$base_sha" == "$(git rev-parse HEAD)" ]]; then
    dirty=$(git status --porcelain=v1 --untracked-files=all)
    [[ -z "$dirty" ]] || fail 'the current checkout has uncommitted changes; a new worktree cannot inherit them'
  fi
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/my-handoff.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
response="$scratch/response.json"
stderr_file="$scratch/stderr"
# A unique branch name avoids asking about collisions or reusing another session.
if [[ "$mode" == worktree ]]; then
  task_name="${task_name}-${scratch##*.}"
fi

call_orca() {
  local status=0 message
  "$orca_cli" "$@" --json >"$response" 2>"$stderr_file" || status=$?
  if ((status != 0)) || ! jq -e '.ok == true and (.result | type == "object")' "$response" >/dev/null 2>&1; then
    if message=$(jq -er '(.error.message // .result.wait.blockedReason) | select(type == "string" and length > 0)' "$response" 2>/dev/null); then
      fail "${message:0:600}; outcome may be partial; do not rerun creation or sending"
    fi
    if [[ -s "$stderr_file" ]]; then
      message=$(head -c 600 "$stderr_file")
      fail "$message; outcome may be partial; do not rerun creation or sending"
    fi
    fail "Orca returned an invalid or unsuccessful response (exit $status); do not rerun creation or sending"
  fi
}

field() {
  jq -er "$1 | select(type == \"string\" and length > 0)" "$response"
}

stage=runtime
call_orca status
jq -e '.result.target.kind == "local" and .result.runtime.reachable == true and .result.runtime.state == "ready"' "$response" >/dev/null || fail 'local Orca runtime is not ready'
stage=source
call_orca worktree show --worktree "path:$repo_root"
source_id=$(field '.result.worktree.id') || fail 'source worktree id is missing'
repo_id=$(field '.result.worktree.repoId') || fail 'source repository id is missing'
source_path=$(field '.result.worktree.path') || fail 'source worktree path is missing'
[[ "$source_path" == "$repo_root" ]] || fail 'Orca resolved a different source worktree'

prompt="作業先のAGENTS.mdを確認し、以下の依頼をこの独立セッションで進めてください。
親の会話履歴は参照せず、必要なコードと資料を作業先で確認してください。依頼の範囲と許可を広げないでください。

$brief"

if [[ "$mode" == worktree ]]; then
  stage=create-worktree
  args=(worktree create --repo "id:$repo_id" --name "$task_name" --no-parent --agent "$agent" --prompt "$prompt")
  if [[ -n "$base_ref" ]]; then
    args+=(--base-branch "$base_sha")
  fi
  call_orca "${args[@]}"
  destination=$(field '.result.worktree.id') || fail 'created worktree id is missing; inspect the workspace by name'
  if warning=$(field '.result.warning'); then
    fail "${warning:0:600}; inspect the created workspace without relaunching"
  fi
  terminal=$(field '.result.agentTerminalHandle') || fail 'agent handle is missing; inspect the created workspace without relaunching'
else
  destination=$source_id
  stage=create-terminal
  call_orca terminal create --worktree "id:$destination" --title "$task_name" --command "$agent"
  terminal=$(field '.result.terminal.handle') || fail 'created terminal handle is missing; inspect the workspace without relaunching'
  stage=wait-ready
  call_orca terminal wait --terminal "$terminal" --for tui-idle --timeout-ms 60000
  jq -e '.result.wait.satisfied == true and .result.wait.status == "running"' "$response" >/dev/null || fail 'agent is not ready; no prompt was sent'
  stage=send-prompt
  call_orca terminal send --terminal "$terminal" --text "$prompt" --enter
  jq -e '.result.send.accepted == true' "$response" >/dev/null || fail 'prompt was not accepted; inspect the terminal before sending again'
fi

jq -cn --arg name "$task_name" --arg mode "$mode" --arg worktree "$destination" --arg terminal "$terminal" \
  '{status:"prompt_sent",name:$name,mode:$mode,worktree:$worktree,terminal:$terminal}'
