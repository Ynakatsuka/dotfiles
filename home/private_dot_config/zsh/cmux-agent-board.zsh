# Track foreground command activity for each cmux terminal surface.
if [[ -n "${CMUX_WORKSPACE_ID:-}" && -n "${CMUX_SURFACE_ID:-}" ]]; then
  autoload -Uz add-zsh-hook
  typeset -g _cmux_agent_board_prompt_seen=false

  _cmux_agent_board_command_started() {
    "$HOME/.local/bin/cmux-agent-board-state" working >/dev/null
  }

  _cmux_agent_board_command_finished() {
    # Let cmux assign its directory-based title before the first prompt.
    if [[ "$_cmux_agent_board_prompt_seen" == false ]]; then
      _cmux_agent_board_prompt_seen=true
      return
    fi
    "$HOME/.local/bin/cmux-agent-board-state" idle >/dev/null
  }

  add-zsh-hook preexec _cmux_agent_board_command_started
  add-zsh-hook precmd _cmux_agent_board_command_finished
fi
