#!/bin/bash
# StatusLine proxy for Claude Code Viewer (CCV)
#
# Replaces the statusLine command. Reads JSON from stdin,
# POSTs rate_limits to CCV (fire-and-forget), persists a non-secret local
# snapshot for cmux, then passes through to the downstream command (default:
# ccusage).
#
# Safe on machines without CCV: curl fails fast and the
# downstream command still produces the status line.
#
# Environment variables:
#   CCV_PORT          - CCV server port (default: 3434)
#   CCV_DOWNSTREAM    - Downstream command (default: npx -y ccusage statusline)
#   CMUX_CLAUDE_RATE_LIMITS_STATE - Local non-secret rate limit snapshot path

CCV_PORT="${CCV_PORT:-3434}"
CCV_DOWNSTREAM="${CCV_DOWNSTREAM:-npx -y ccusage statusline}"
CLAUDE_RATE_LIMITS_STATE="${CMUX_CLAUDE_RATE_LIMITS_STATE:-$HOME/.local/state/cmux/claude-rate-limits.json}"

persist_claude_rate_limits() {
  local snapshot state_dir temporary

  snapshot="$(printf '%s' "$INPUT" | jq -ce '
    if (.rate_limits | type) == "object" then
      def selected_window($name):
        if (.rate_limits[$name] | type) == "object" then
          {($name): (.rate_limits[$name]
            | with_entries(select(.key == "used_percentage" or .key == "resets_at")))}
        else
          {}
        end;
      {
        captured_at: (now | floor),
        rate_limits: (selected_window("five_hour") + selected_window("seven_day"))
      }
    else
      empty
    end
  ' 2>/dev/null)" || return 0
  [[ -n "$snapshot" ]] || return 0

  state_dir="$(dirname "$CLAUDE_RATE_LIMITS_STATE")"
  (
    umask 077
    temporary=""
    cleanup() {
      if [[ -n "$temporary" && -e "$temporary" ]]; then
        rm -f "$temporary"
      fi
    }
    trap cleanup EXIT HUP INT TERM

    mkdir -p "$state_dir" || exit 1
    chmod 700 "$state_dir" || exit 1
    temporary="$(mktemp "$state_dir/.claude-rate-limits.json.XXXXXX")" || exit 1
    printf '%s\n' "$snapshot" >"$temporary" || exit 1
    chmod 600 "$temporary" || exit 1
    mv -f "$temporary" "$CLAUDE_RATE_LIMITS_STATE" || exit 1
    temporary=""
  ) || printf '%s\n' 'cmux Agent Board: failed to persist Claude rate limits' >&2
}

INPUT=$(cat)

if echo "$INPUT" | grep -q '"rate_limits"'; then
  persist_claude_rate_limits
  PAYLOAD=$(echo "$INPUT" | jq -c '{rate_limits: .rate_limits}' 2>/dev/null)
  if [ -n "$PAYLOAD" ] && [ "$PAYLOAD" != "null" ]; then
    curl -s -X POST "http://localhost:${CCV_PORT}/api/agents/claude/status-line" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      --max-time 2 &>/dev/null &
  fi
fi

echo "$INPUT" | $CCV_DOWNSTREAM
