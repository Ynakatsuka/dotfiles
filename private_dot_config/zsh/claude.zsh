#
# Claude Code
#
function cl() {
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -f "$git_root/.claude/mcp.json" ]; then
        ENABLE_TOOL_SEARCH=true claude --mcp-config="$git_root/.claude/mcp.json" "$@" --permission-mode auto
    else
        ENABLE_TOOL_SEARCH=true claude "$@" --permission-mode auto
    fi
}

# Collect Claude Code sessions for current directory
_collect_claude_sessions() {
    local claude_projects_dir="$HOME/.claude/projects"
    local current_path="$(pwd)"
    local current_dir="${current_path//\//-}"
    current_dir="${current_dir//./-}"
    current_dir="${current_dir#-}"
    local project_dir="$claude_projects_dir/-$current_dir"

    [[ -d "$project_dir" ]] || return 0

    for file in "$project_dir"/*.jsonl(N); do
        [[ -f "$file" ]] || continue
        local name=$(basename "$file" .jsonl)
        [[ "$name" == agent-* ]] && continue
        [[ ${#name} -ne 36 ]] && continue

        local summary=$(head -1 "$file" | jq -r '.summary // empty' 2>/dev/null)
        [[ -z "$summary" ]] && summary="(no summary)"

        local msg_count=$(grep -c '"type":"user"' "$file" 2>/dev/null || echo "0")

        local mtime=$(stat -f "%m" "$file" 2>/dev/null)
        printf "%s\tclaude\t%s\t%s\t%s\t%s\t%s\n" "$mtime" "$(date -r "$mtime" "+%m/%d %H:%M")" "${msg_count}msg" "$summary" "$name" "$file"
    done
}

# Collect Codex sessions for current directory
_collect_codex_sessions() {
    local codex_sessions_dir="$HOME/.codex/sessions"
    [[ -d "$codex_sessions_dir" ]] || return 0

    local current_path="$(pwd)"

    find "$codex_sessions_dir" -name "*.jsonl" -print0 2>/dev/null | while IFS= read -r -d '' file; do
        local cwd=$(head -1 "$file" | jq -r 'select(.type=="session_meta") | .payload.cwd // empty' 2>/dev/null)
        [[ "$cwd" == "$current_path" ]] || continue

        local session_id=$(head -1 "$file" | jq -r 'select(.type=="session_meta") | .payload.id // empty' 2>/dev/null)
        [[ -n "$session_id" ]] || continue

        local msg_count=$(jq -r 'select(.type=="response_item" and .payload.role=="user") | .payload.role' "$file" 2>/dev/null | wc -l | tr -d ' ')

        local mtime=$(stat -f "%m" "$file" 2>/dev/null)
        printf "%s\tcodex\t%s\t%s\t(codex session)\t%s\t%s\n" "$mtime" "$(date -r "$mtime" "+%m/%d %H:%M")" "${msg_count}msg" "$session_id" "$file"
    done
}

# fzf session resume: Claude Code + Codex (current directory only)
function fzf-session-resume() {
    local sessions=$(
        { _collect_claude_sessions; _collect_codex_sessions } | sort -t$'\t' -k1 -nr | cut -f2-
    )

    if [[ -z "$sessions" ]]; then
        zle -M "No sessions found for $(pwd)"
        return 1
    fi

    local selected=$(echo "$sessions" | fzf \
        --prompt="Session> " \
        --height=50% \
        --reverse \
        --ansi \
        --delimiter=$'\t' \
        --with-nth=1,2,3,4,5 \
        --preview='
            tool=$(echo {} | awk -F"\t" "{print \$1}")
            filepath=$(echo {} | awk -F"\t" "{print \$6}")
            if [ "$tool" = "claude" ]; then
                jq -r "select(.type==\"user\") | .message.content" "$filepath" 2>/dev/null | head -30
            else
                jq -r "select(.type==\"response_item\" and .payload.role==\"user\") | .payload.content[] | if type == \"object\" then .text // empty else . end" "$filepath" 2>/dev/null | grep -v "^#" | grep -v "^<" | grep -v "^$" | head -30
            fi
        ' \
        --preview-window=right:40%:wrap)

    if [[ -n "$selected" ]]; then
        local tool=$(echo "$selected" | awk -F'\t' '{print $1}')
        local session_id=$(echo "$selected" | awk -F'\t' '{print $5}')
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
bindkey '^l' fzf-session-resume
