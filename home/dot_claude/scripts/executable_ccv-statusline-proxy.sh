#!/bin/bash
# StatusLine proxy for Claude Code Viewer (CCV)
#
# Replaces the statusLine command. Reads JSON from stdin,
# POSTs rate_limits to CCV (fire-and-forget), then passes
# through to the downstream command (default: ccusage).
#
# Safe on machines without CCV: curl fails fast and the
# downstream command still produces the status line.
#
# Environment variables:
#   CCV_PORT          - CCV server port (default: 3434)
#   CCV_DOWNSTREAM    - Downstream command (default: npx -y ccusage statusline)

CCV_PORT="${CCV_PORT:-3434}"
CCV_DOWNSTREAM="${CCV_DOWNSTREAM:-npx -y ccusage statusline}"

INPUT=$(cat)

if echo "$INPUT" | grep -q '"rate_limits"'; then
  PAYLOAD=$(echo "$INPUT" | jq -c '{rate_limits: .rate_limits}' 2>/dev/null)
  if [ -n "$PAYLOAD" ] && [ "$PAYLOAD" != "null" ]; then
    curl -s -X POST "http://localhost:${CCV_PORT}/api/agents/claude/status-line" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      --max-time 2 &>/dev/null &
  fi
fi

echo "$INPUT" | $CCV_DOWNSTREAM
