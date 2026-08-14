#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly USAGE_SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_cmux-agent-board-usage"
readonly STATUSLINE_PROXY="$REPO_ROOT/home/dot_claude/scripts/executable_ccv-statusline-proxy.sh"
readonly SIDEBAR="$REPO_ROOT/home/dot_local/share/cmux/agent-board.swift"

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/cmux-agent-board-usage-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

cache_file="$test_dir/state/agent-board-usage.json"
claude_state_file="$test_dir/state/claude-rate-limits.json"
codex_log="$test_dir/codex-log"
claude_log="$test_dir/claude-log"
cursor_log="$test_dir/cursor-log"
mock_codex="$test_dir/codex-app-server"
mock_claude="$test_dir/claude"
mock_cursor="$test_dir/cursor-agent"

python3 - "$SIDEBAR" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
assert source.index('Text("Diff")') < source.index('Text("Usage")')
assert 'usageProviderRow("codex", "Codex")' in source
assert 'usageProviderRow("claude", "Claude Code")' in source
assert 'usageProviderRow("cursor", "Cursor")' in source
assert 'func usageBar(_ progress: Double) -> some View {' in source
assert 'ForEach(0..<20)' in source
assert 'Double(index) < progress * 20 ? usageTint(progress) : "#FFFFFF12"' in source
assert 'usageBar(progress)' in source
assert 'ProgressView(value: progress' not in source
assert 'func usageResetRemaining(_ resetAt: Double, _ now: Double) -> String {' in source
assert 'usageResetAt(provider, field)' in source
assert 'Double(clock.epoch)' in source
assert 'Text("あと \\(resetRemaining)")' in source
assert '.font(.system(size: 10, design: .monospaced))' in source
assert 'if progress >= 0.9 { return "#FF453A" }' in source
assert 'if progress >= 0.7 { return "#FF9F0A" }' in source
assert 'if progress >= 0.3 { return "#FFD60A" }' in source
assert 'return "#30D158"' in source
assert 'usageMetricRow(provider, "five_hour", "5h")' in source
assert 'usageMetricRow(provider, "seven_day", "Week")' in source
assert 'usageMetricRow(provider, "fable_week", "Fable")' in source
assert 'let accountName = usageValue(provider, "account_name")' in source
assert '.padding(6)' in source
assert '.font(.system(size: 12))' in source
PY

cat >"$mock_codex" <<'PYTHON'
#!/usr/bin/env python3
import json
import os
import sys

log_path = os.environ["MOCK_CODEX_LOG"]
for line in sys.stdin:
    message = json.loads(line)
    with open(log_path, "a", encoding="utf-8") as log:
        log.write(message["method"] + "\n")
    if message.get("id") == 1:
        print(json.dumps({"jsonrpc": "2.0", "id": 1, "result": {}}), flush=True)
        if os.environ.get("MOCK_CODEX_MODE") == "close_after_initialize":
            break
    elif message.get("id") == 2:
        print(json.dumps({
            "jsonrpc": "2.0",
            "id": 2,
            "result": {"account": {"type": "chatgpt", "email": "codex@example.com", "name": "Codex Personal"}},
        }), flush=True)
    elif message.get("id") == 3:
        if os.environ.get("MOCK_CODEX_MODE") == "error":
            print(json.dumps({"jsonrpc": "2.0", "id": 3, "error": {"message": "failed"}}), flush=True)
        else:
            print(json.dumps({
                "jsonrpc": "2.0",
                "id": 3,
                "result": {
                    "rateLimits": {"limitId": "not-codex"},
                    "rateLimitsByLimitId": {
                        "codex": {
                            "primary": {"windowDurationMins": 10080, "usedPercent": 67, "resetsAt": 2000000},
                            "secondary": {"windowDurationMins": 300, "usedPercent": 23.5, "resetsAt": 2000},
                        }
                    },
                },
            }), flush=True)
        break
PYTHON
chmod +x "$mock_codex"

cat >"$mock_claude" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_CLAUDE_LOG"
if [[ "$*" == 'auth status --json' ]]; then
  printf '%s\n' '{"loggedIn":true,"email":"claude@example.com","orgName":"Claude Team"}'
elif [[ "$*" == *'-p /usage'* ]]; then
  if [[ "${MOCK_CLAUDE_USAGE_MODE:-}" == 'error' ]]; then
    exit 1
  fi
  printf '%s\n' '{"subtype":"success","result":"Current session: 12% used · resets Jan 1 at 1:00am (UTC)\nCurrent week (all models): 34% used · resets Jan 8 at 1am (UTC)\nCurrent week (Fable): 56.5% used · resets Jan 8 at 1am (UTC)","total_cost_usd":0}'
else
  exit 1
fi
MOCK
chmod +x "$mock_claude"

cat >"$mock_cursor" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'status\n' >>"$MOCK_CURSOR_LOG"
printf '%s\n' '{"isAuthenticated":true,"userInfo":{"email":"cursor@example.com","name":"Cursor Personal"}}'
MOCK
chmod +x "$mock_cursor"

mkdir -p "$(dirname "$claude_state_file")"
cat >"$claude_state_file" <<'JSON'
{"captured_at":940,"rate_limits":{"five_hour":{"used_percentage":12},"seven_day":{"used_percentage":34}}}
JSON

run_usage() {
  MOCK_CODEX_LOG="$codex_log" \
    MOCK_CLAUDE_LOG="$claude_log" \
    MOCK_CURSOR_LOG="$cursor_log" \
    CMUX_AGENT_BOARD_USAGE_CACHE="$cache_file" \
    CMUX_CLAUDE_RATE_LIMITS_STATE="$claude_state_file" \
    CMUX_AGENT_BOARD_CODEX_COMMAND="$mock_codex" \
    CMUX_AGENT_BOARD_CLAUDE_COMMAND="$mock_claude" \
    CMUX_AGENT_BOARD_CURSOR_COMMAND="$mock_cursor" \
    CMUX_AGENT_BOARD_USAGE_NOW="$1" \
    "$USAGE_SCRIPT"
}

first_snapshot="$(run_usage 1000)"
jq -e '
  .schema_version == 4
  and .refreshed_at == 1000
  and .providers.codex.account == "codex@example.com"
  and .providers.codex.account_name == "Codex Personal"
  and .providers.codex.five_hour == 23.5
  and .providers.codex.seven_day == 67
  and .providers.codex.five_hour_reset_at == 2000
  and .providers.codex.seven_day_reset_at == 2000000
  and .providers.claude.account == "claude@example.com"
  and .providers.claude.account_name == "Claude Team"
  and .providers.claude.five_hour == 12
  and .providers.claude.seven_day == 34
  and .providers.claude.fable_week == 56.5
  and .providers.claude.five_hour_reset_at == 3600
  and .providers.claude.seven_day_reset_at == 608400
  and .providers.claude.fable_week_reset_at == 608400
  and .providers.claude.detail == "age 1m"
  and .providers.cursor.account == "cursor@example.com"
  and .providers.cursor.account_name == "Cursor Personal"
  and .providers.cursor.five_hour == null
  and .providers.cursor.seven_day == null
  and .providers.cursor.five_hour_reset_at == null
  and .providers.cursor.detail == "monthly only"
' <<<"$first_snapshot" >/dev/null
grep -Fxq 'initialize' "$codex_log"
grep -Fxq 'initialized' "$codex_log"
grep -Fxq 'account/read' "$codex_log"
grep -Fxq 'account/rateLimits/read' "$codex_log"
[[ "$(wc -l <"$claude_log" | tr -d ' ')" == '2' ]]
grep -Fxq 'auth status --json' "$claude_log"
grep -Fq -- '--safe-mode -p /usage --output-format json' "$claude_log"
grep -Fq -- '--no-session-persistence --max-budget-usd 0.000001' "$claude_log"
[[ "$(wc -l <"$cursor_log" | tr -d ' ')" == '1' ]]
python3 - "$USAGE_SCRIPT" <<'PY'
import runpy
import sys

module = runpy.run_path(sys.argv[1], run_name="cmux_agent_board_usage_test")
snapshot = module["codex_snapshot"]
windows = module["codex_windows"]
reset_times = module["codex_reset_times"]
send_json = module["send_json"]
fable_week = module["claude_fable_week"]
claude_resets = module["claude_reset_times"]


class BrokenPipeStdin:
    def write(self, value):
        raise BrokenPipeError

    def flush(self):
        raise AssertionError("flush must not be called after a broken write")


class BrokenPipeProcess:
    stdin = BrokenPipeStdin()


try:
    send_json(BrokenPipeProcess(), {"id": 1})
except RuntimeError:
    pass
else:
    raise AssertionError("BrokenPipeError was not converted to RuntimeError")

fallback = snapshot({
    "rateLimits": {
        "limitId": "codex",
        "primary": {"windowDurationMins": 300, "usedPercent": 8.25},
        "secondary": {"windowDurationMins": 10080, "usedPercent": 91},
    }
})
assert windows(fallback) == (8.25, 91)
assert reset_times({
    "primary": {"windowDurationMins": 300, "resetsAt": 2000},
    "secondary": {"windowDurationMins": 10080, "resetsAt": 3000},
}) == (2000, 3000)
assert snapshot({"rateLimits": {"limitId": "other"}}) is None
assert windows({
    "primary": {"windowDurationMins": 300, "usedPercent": 7},
    "secondary": {"windowDurationMins": 10080, "usedPercent": 81},
    "unexpected": {"windowDurationMins": 300, "usedPercent": 99},
}) == (7, 81)
assert fable_week({
    "subtype": "success",
    "result": "Current week (Fable): 7.25% used",
    "total_cost_usd": 0,
}) == 7.25
assert fable_week({
    "subtype": "success",
    "result": "Current week (Fable): 7% used",
    "total_cost_usd": 0.01,
}) is None
assert fable_week({"subtype": "success", "result": "Fable unavailable", "total_cost_usd": 0}) is None
assert claude_resets({
    "subtype": "success",
    "result": (
        "Current session: 7% used · resets Jan 1 at 1:00am (UTC)\n"
        "Current week (all models): 8% used · resets Jan 8 at 1am (UTC)\n"
        "Current week (Fable): 9% used · resets Jan 8 at 1am (UTC)"
    ),
}, 1000) == (3600, 608400, 608400)
PY
python3 - "$cache_file" <<'PY'
import os
import stat
import sys

assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600
assert stat.S_IMODE(os.stat(os.path.dirname(sys.argv[1])).st_mode) == 0o700
PY

second_snapshot="$(run_usage 1100)"
[[ "$second_snapshot" == "$first_snapshot" ]]
[[ "$(wc -l <"$claude_log" | tr -d ' ')" == '2' ]]
[[ "$(wc -l <"$cursor_log" | tr -d ' ')" == '1' ]]
[[ "$(wc -l <"$codex_log" | tr -d ' ')" == '4' ]]

fable_error_cache="$test_dir/fable-error/agent-board-usage.json"
fable_error_snapshot="$(
  MOCK_CODEX_LOG="$test_dir/fable-error-codex-log" \
    MOCK_CLAUDE_LOG="$test_dir/fable-error-claude-log" \
    MOCK_CURSOR_LOG="$test_dir/fable-error-cursor-log" \
    MOCK_CLAUDE_USAGE_MODE=error \
    CMUX_AGENT_BOARD_USAGE_CACHE="$fable_error_cache" \
    CMUX_CLAUDE_RATE_LIMITS_STATE="$claude_state_file" \
    CMUX_AGENT_BOARD_CODEX_COMMAND="$mock_codex" \
    CMUX_AGENT_BOARD_CLAUDE_COMMAND="$mock_claude" \
    CMUX_AGENT_BOARD_CURSOR_COMMAND="$mock_cursor" \
    CMUX_AGENT_BOARD_USAGE_NOW=1200 \
    "$USAGE_SCRIPT"
)"
jq -e '
  .providers.claude.status == "ok"
  and .providers.claude.five_hour == 12
  and .providers.claude.seven_day == 34
  and .providers.claude.fable_week == null
' <<<"$fable_error_snapshot" >/dev/null

error_snapshot="$(MOCK_CODEX_MODE=error run_usage 1300)"
jq -e '
  .refreshed_at == 1300
  and .providers.codex.status == "error"
  and .providers.codex.account == null
  and .providers.codex.five_hour == null
  and .providers.codex.seven_day == null
' <<<"$error_snapshot" >/dev/null
[[ "$(wc -l <"$claude_log" | tr -d ' ')" == '4' ]]
[[ "$(wc -l <"$cursor_log" | tr -d ' ')" == '2' ]]

broken_pipe_cache="$test_dir/broken-pipe/agent-board-usage.json"
broken_pipe_snapshot="$(
  MOCK_CODEX_LOG="$codex_log" \
    MOCK_CLAUDE_LOG="$claude_log" \
    MOCK_CURSOR_LOG="$cursor_log" \
    MOCK_CODEX_MODE=close_after_initialize \
    CMUX_AGENT_BOARD_USAGE_CACHE="$broken_pipe_cache" \
    CMUX_CLAUDE_RATE_LIMITS_STATE="$claude_state_file" \
    CMUX_AGENT_BOARD_CODEX_COMMAND="$mock_codex" \
    CMUX_AGENT_BOARD_CLAUDE_COMMAND="$mock_claude" \
    CMUX_AGENT_BOARD_CURSOR_COMMAND="$mock_cursor" \
    CMUX_AGENT_BOARD_USAGE_NOW=1400 \
    "$USAGE_SCRIPT"
)"
[[ -f "$broken_pipe_cache" ]]
jq -e '
  .providers.codex.status == "error"
  and .providers.claude.status == "ok"
  and .providers.cursor.status == "ok"
' <<<"$broken_pipe_snapshot" >/dev/null

stale_cache="$test_dir/stale/agent-board-usage.json"
stale_snapshot="$(
  MOCK_CODEX_LOG="$codex_log" \
    MOCK_CLAUDE_LOG="$claude_log" \
    MOCK_CURSOR_LOG="$cursor_log" \
    CMUX_AGENT_BOARD_USAGE_CACHE="$stale_cache" \
    CMUX_CLAUDE_RATE_LIMITS_STATE="$claude_state_file" \
    CMUX_AGENT_BOARD_CODEX_COMMAND="$mock_codex" \
    CMUX_AGENT_BOARD_CLAUDE_COMMAND="$mock_claude" \
    CMUX_AGENT_BOARD_CURSOR_COMMAND="$mock_cursor" \
    CMUX_AGENT_BOARD_USAGE_NOW=1900 \
    "$USAGE_SCRIPT"
)"
jq -e '.providers.claude.detail == "stale 16m"' <<<"$stale_snapshot" >/dev/null

proxy_state="$test_dir/proxy/claude-rate-limits.json"
proxy_input='{"rate_limits":{"five_hour":{"used_percentage":55,"resets_at":"2026-08-14T00:00:00Z","unknown":"must-not-persist"},"seven_day":{"used_percentage":44,"secret_like":"must-not-persist"},"future_window":{"used_percentage":99}},"session_id":"must-not-persist"}'
proxy_output="$(printf '%s\n' "$proxy_input" |
  CMUX_CLAUDE_RATE_LIMITS_STATE="$proxy_state" \
    CCV_DOWNSTREAM=cat \
    bash "$STATUSLINE_PROXY")"
[[ "$proxy_output" == "$proxy_input" ]]
jq -e '
  (.captured_at | type) == "number"
  and .rate_limits.five_hour.used_percentage == 55
  and .rate_limits.five_hour.resets_at == "2026-08-14T00:00:00Z"
  and .rate_limits.seven_day.used_percentage == 44
  and (.rate_limits | keys == ["five_hour", "seven_day"])
  and (.rate_limits.five_hour | keys == ["resets_at", "used_percentage"])
  and (.rate_limits.seven_day | keys == ["used_percentage"])
  and (has("session_id") | not)
  and (.rate_limits | has("future_window") | not)
  and (.rate_limits.five_hour | has("unknown") | not)
  and (.rate_limits.seven_day | has("secret_like") | not)
' "$proxy_state" >/dev/null
python3 - "$proxy_state" <<'PY'
import os
import stat
import sys

assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600
assert stat.S_IMODE(os.stat(os.path.dirname(sys.argv[1])).st_mode) == 0o700
PY

failing_mv_dir="$test_dir/failing-mv-bin"
failing_state="$test_dir/failing/claude-rate-limits.json"
mkdir -p "$failing_mv_dir"
cat >"$failing_mv_dir/mv" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
chmod +x "$failing_mv_dir/mv"
failed_output="$(printf '%s\n' "$proxy_input" |
  PATH="$failing_mv_dir:$PATH" \
    CMUX_CLAUDE_RATE_LIMITS_STATE="$failing_state" \
    CCV_DOWNSTREAM=cat \
    bash "$STATUSLINE_PROXY" 2>"$test_dir/proxy-error")"
[[ "$failed_output" == "$proxy_input" ]]
grep -Fq 'cmux Agent Board: failed to persist Claude rate limits' "$test_dir/proxy-error"
if find "$(dirname "$failing_state")" -name '.claude-rate-limits.json.*' -print -quit | grep -q .; then
  printf 'failed Claude snapshot write left a temporary file\n' >&2
  exit 1
fi

printf 'cmux Agent Board usage tests passed\n'
