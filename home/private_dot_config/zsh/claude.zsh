#
# Claude Code
#
function cl() {
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -f "$git_root/.claude/mcp.json" ]; then
        claude --mcp-config="$git_root/.claude/mcp.json" "$@" --dangerously-skip-permissions
    else
        claude "$@" --dangerously-skip-permissions
    fi
}

# fzf session resume: Claude Code + Codex (current directory only)
function fzf-session-resume() {
    local session_limit="${FZF_SESSION_RESUME_LIMIT:-100}"
    if [[ ! "$session_limit" =~ '^[1-9][0-9]*$' ]]; then
        zle -M "FZF_SESSION_RESUME_LIMIT must be a positive integer"
        return 1
    fi

    local sessions
    if ! sessions=$(session-resume-list --limit "$session_limit"); then
        zle -M "Failed to read sessions; see the error above"
        return 1
    fi

    if [[ -z "$sessions" ]]; then
        zle -M "No sessions found for $(pwd)"
        return 1
    fi

    local selected=$(print -r -- "$sessions" | fzf \
        --prompt="Session> " \
        --height=50% \
        --reverse \
        --wrap \
        --delimiter=$'\t' \
        --with-nth=1,2,3,4 \
        --preview='session-resume-list --preview {1} {6}' \
        --preview-window=right:40%:wrap)

    if [[ -n "$selected" ]]; then
        local -a fields
        fields=("${(@ps:\t:)selected}")
        local tool="${fields[1]}"
        local session_id="${fields[5]}"
        if [[ "$tool" == "claude" ]]; then
            BUFFER="cl --resume=$session_id"
        else
            BUFFER="codex resume $session_id"
        fi
        zle accept-line
    fi
    zle reset-prompt
}
zle -N fzf-session-resume
# Bind to Ctrl-K and restore Ctrl-L to clear-screen.
bindkey '^K' fzf-session-resume
bindkey '^L' clear-screen
