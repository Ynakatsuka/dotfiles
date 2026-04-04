#!/usr/bin/env bash
# Ralph Loop — autonomous task execution with context reset
# Usage: ralph.sh [MAX_ITERATIONS] [AGENT_COMMAND]
#   MAX_ITERATIONS: Maximum loop count (default: 20)
#   AGENT_COMMAND:  Agent CLI command (default: claude)
#
# Required files in working directory:
#   ralph-prompt.md  — Agent instructions
#   ralph-prd.json   — Task definitions
#
# The loop runs the agent once per iteration, piping ralph-prompt.md as input.
# The agent reads ralph-prd.json, picks ONE incomplete task, implements it,
# runs validation, updates status, and exits.
# If the agent outputs "RALPH_COMPLETE", all tasks are done and the loop stops.

set -euo pipefail

MAX_ITERATIONS="${1:-20}"
AGENT_CMD="${2:-claude}"
PROMPT_FILE="ralph-prompt.md"
PRD_FILE="ralph-prd.json"
PROGRESS_FILE="ralph-progress.md"

# --- Validation -----------------------------------------------------------
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: $PROMPT_FILE not found. Run '/my-ralph' to generate it." >&2
  exit 1
fi

if [[ ! -f "$PRD_FILE" ]]; then
  echo "ERROR: $PRD_FILE not found. Run '/my-ralph' to generate it." >&2
  exit 1
fi

# Ensure progress file exists
touch "$PROGRESS_FILE"

# --- Main loop -------------------------------------------------------------
iteration=0
while (( iteration < MAX_ITERATIONS )); do
  iteration=$((iteration + 1))
  echo ""
  echo "=========================================="
  echo " Ralph Loop — Iteration $iteration / $MAX_ITERATIONS"
  echo " $(date '+%Y-%m-%d %H:%M:%S')"
  echo "=========================================="

  # Run agent with prompt piped via stdin
  # --allowedTools restricts to safe tools (adjust as needed)
  output=$($AGENT_CMD -p "$(cat "$PROMPT_FILE")" \
    --allowedTools "Read,Write,Edit,Glob,Grep,Bash(git *),Bash(npm *),Bash(npx *),Bash(pnpm *),Bash(yarn *),Bash(bun *),Bash(cargo *),Bash(make *),Bash(python *),Bash(pytest *),Bash(ruff *),Bash(go *),Bash(mise *)" \
    2>&1) || true

  echo "$output" | tail -5

  # Check for completion signal
  if echo "$output" | grep -q "RALPH_COMPLETE"; then
    echo ""
    echo "=========================================="
    echo " All tasks complete! ($iteration iterations)"
    echo " $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    exit 0
  fi

  # Brief pause between iterations
  sleep 2
done

echo ""
echo "=========================================="
echo " Max iterations reached ($MAX_ITERATIONS)"
echo " Check $PRD_FILE for remaining tasks."
echo "=========================================="
exit 1
