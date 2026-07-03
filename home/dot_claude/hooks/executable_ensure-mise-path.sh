#!/usr/bin/env bash
# Prepend mise shims to PATH for every Bash tool invocation, so mise-managed
# CLIs (gcloud, bq, gh, aws, etc.) resolve even when Claude Code was launched
# from a shell whose PATH did not yet include the shims directory.
#
# Claude Code's Bash tool inherits PATH directly from the Claude process and
# does NOT re-source ~/.zshenv, so setting PATH here via updatedInput is the
# only reliable way to affect the executed command's shell.
#
# Runs BEFORE rtk-rewrite.sh; rtk-rewrite handles PATH-prefixed commands
# correctly (rewrites only the suffix), so ordering preserves rtk token savings.
# Requires: jq.

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# Resolve mise shims directory with override fallback chain:
# MISE_DATA_DIR > XDG_DATA_HOME/mise > $HOME/.local/share/mise.
# mise docs confirm this layout on both Linux and macOS — no Library/Application Support detour.
SHIMS="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims"

# Skip if the user's shims are already prepended (idempotent across chained hooks).
case "$CMD" in
  *"PATH=\"$SHIMS:"*|*"PATH=$SHIMS:"*) exit 0 ;;
esac

# Skip if the shims dir doesn't exist on this host.
[ -d "$SHIMS" ] || exit 0

NEW_CMD="export PATH=\"$SHIMS:\$PATH\"; $CMD"

UPDATED_INPUT=$(echo "$INPUT" | jq -c --arg cmd "$NEW_CMD" '.tool_input | .command = $cmd')

jq -n --argjson updated "$UPDATED_INPUT" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "updatedInput": $updated
  }
}'
