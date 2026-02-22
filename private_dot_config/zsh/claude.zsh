#
# Claude Code
#
function cl() {
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -f "$git_root/.claude/mcp.json" ]; then
        ENABLE_TOOL_SEARCH=true claude --mcp-config="$git_root/.claude/mcp.json" "$@" "--dangerously-skip-permissions"
    else
        ENABLE_TOOL_SEARCH=true claude "$@" "--dangerously-skip-permissions"
    fi
}

# fzf Claude Code session resume (current directory only)
function fzf-claude-resume() {
    local claude_projects_dir="$HOME/.claude/projects"

    local current_path="$(pwd)"
    local current_dir="${current_path//\//-}"
    current_dir="${current_dir//./-}"
    current_dir="${current_dir#-}"
    local project_dir="$claude_projects_dir/-$current_dir"

    if [[ ! -d "$project_dir" ]]; then
        zle -M "No Claude sessions for this directory: $project_dir"
        return 1
    fi

    local sessions=$(
        for file in "$project_dir"/*.jsonl(N); do
            [[ -f "$file" ]] || continue
            local name=$(basename "$file" .jsonl)
            [[ "$name" == agent-* ]] && continue
            [[ ${#name} -ne 36 ]] && continue

            local summary=$(head -1 "$file" | jq -r '.summary // empty' 2>/dev/null)
            [[ -z "$summary" ]] && summary="(no summary)"

            local msg_count=$(grep -c '"type":"user"' "$file" 2>/dev/null || echo "0")

            local mtime=$(stat -f "%m" "$file" 2>/dev/null)
            printf "%s\t%s\t%s\t%s\t%s\n" "$mtime" "$(date -r "$mtime" "+%m/%d %H:%M")" "${msg_count}msg" "$summary" "$name"
        done | sort -t$'\t' -k1 -nr | cut -f2-
    )

    if [[ -z "$sessions" ]]; then
        zle -M "No Claude sessions found"
        return 1
    fi

    local selected=$(echo "$sessions" | fzf \
        --prompt="Claude Session> " \
        --height=50% \
        --reverse \
        --delimiter=$'\t' \
        --with-nth=1,2,3,4 \
        --preview="echo {} | awk -F'\t' '{print \$4}' | xargs -I{} sh -c 'cat \"$project_dir/{}.jsonl\" | jq -r \"select(.type==\\\"user\\\") | .message.content\" 2>/dev/null | head -20'" \
        --preview-window=right:40%:wrap)

    if [[ -n "$selected" ]]; then
        local session_id=$(echo "$selected" | awk -F'\t' '{print $4}')
        BUFFER="cl -r $session_id"
        zle accept-line
    fi
    zle reset-prompt
}
zle -N fzf-claude-resume
bindkey '^l' fzf-claude-resume
