#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly STATUSLINE_PROXY="$REPO_ROOT/home/dot_claude/scripts/executable_ccv-statusline-proxy.sh"

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/ccv-statusline-proxy-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

proxy_mock_bin="$test_dir/proxy-bin"
proxy_curl_arguments="$test_dir/proxy-curl-arguments"
proxy_payload="$test_dir/proxy-payload.json"
mkdir -p "$proxy_mock_bin"
cat >"$proxy_mock_bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$MOCK_CURL_ARGUMENTS"
while (($#)); do
  if [[ "$1" == '-d' ]]; then
    printf '%s\n' "$2" >"$MOCK_CURL_PAYLOAD"
    break
  fi
  shift
done
if [[ "${MOCK_CURL_FAIL:-0}" == '1' ]]; then
  : >"$MOCK_CURL_FAILURE_MARKER"
  exit 1
fi
MOCK
chmod +x "$proxy_mock_bin/curl"

proxy_input='{"rate_limits":{"five_hour":{"used_percentage":55,"resets_at":"2026-08-14T00:00:00Z","unknown":"must-not-persist"},"seven_day":{"used_percentage":44,"secret_like":"must-not-persist"},"future_window":{"used_percentage":99}},"session_id":"must-not-persist"}'
proxy_output="$(printf '%s\n' "$proxy_input" |
  PATH="$proxy_mock_bin:$PATH" \
    MOCK_CURL_ARGUMENTS="$proxy_curl_arguments" \
    MOCK_CURL_PAYLOAD="$proxy_payload" \
    CCV_PORT=4321 \
    CCV_DOWNSTREAM=cat \
    bash "$STATUSLINE_PROXY")"
[[ "$proxy_output" == "$proxy_input" ]]
for _ in {1..50}; do
  [[ -s "$proxy_payload" ]] && break
  sleep 0.02
done
[[ -s "$proxy_payload" ]]
grep -Fxq 'http://localhost:4321/api/agents/claude/status-line' "$proxy_curl_arguments"
grep -Fxq 'Content-Type: application/json' "$proxy_curl_arguments"
jq -e '
  keys == ["rate_limits"]
  and .rate_limits.five_hour.used_percentage == 55
  and .rate_limits.five_hour.resets_at == "2026-08-14T00:00:00Z"
  and .rate_limits.five_hour.unknown == "must-not-persist"
  and .rate_limits.seven_day.used_percentage == 44
  and .rate_limits.seven_day.secret_like == "must-not-persist"
  and .rate_limits.future_window.used_percentage == 99
' "$proxy_payload" >/dev/null

failed_proxy_output="$(printf '%s\n' "$proxy_input" |
  PATH="$proxy_mock_bin:$PATH" \
    MOCK_CURL_ARGUMENTS="$proxy_curl_arguments" \
    MOCK_CURL_PAYLOAD="$proxy_payload" \
    MOCK_CURL_FAILURE_MARKER="$test_dir/proxy-curl-failure" \
    MOCK_CURL_FAIL=1 \
    CCV_PORT=4321 \
    CCV_DOWNSTREAM=cat \
    bash "$STATUSLINE_PROXY")"
[[ "$failed_proxy_output" == "$proxy_input" ]]
for _ in {1..50}; do
  [[ -e "$test_dir/proxy-curl-failure" ]] && break
  sleep 0.02
done
[[ -e "$test_dir/proxy-curl-failure" ]]

printf 'ccv statusline proxy tests passed\n'
