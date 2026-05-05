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

_format_session_tokens() {
    local tokens="$1"
    [[ "$tokens" == <-> ]] || {
        printf "%s" "-"
        return 0
    }

    if (( tokens >= 1000000 )); then
        printf "%.1fM" "$(( tokens / 1000000.0 ))"
    elif (( tokens >= 1000 )); then
        printf "%.0fk" "$(( tokens / 1000.0 ))"
    else
        printf "%d" "$tokens"
    fi
}

# Collect Claude Code sessions for current directory.
# Uses one jq pass per file; Ctrl-K latency is dominated by per-session forks.
_collect_claude_sessions() {
    local claude_projects_dir="$HOME/.claude/projects"
    local current_path="$(pwd)"
    local current_dir="${current_path//\//-}"
    current_dir="${current_dir//./-}"
    current_dir="${current_dir#-}"
    local project_dir="$claude_projects_dir/-$current_dir"

    [[ -d "$project_dir" ]] || return 0

    zmodload -F zsh/stat b:zstat 2>/dev/null
    zmodload -F zsh/datetime b:strftime 2>/dev/null

    local file name summary title turns tokens token_display mtime date_str
    local -A st
    for file in "$project_dir"/*.jsonl(N); do
        name="${${file:t}%.jsonl}"
        [[ "$name" == agent-* ]] && continue
        [[ ${#name} -ne 36 ]] && continue

        summary=$(jq -r -n '
            reduce inputs as $item (
                {title: "", turns: 0, tokens: 0, has_tokens: false};
                .title = (
                    if .title == "" and (($item.summary? // "") != "") then
                        ($item.summary | gsub("[[:space:]]+"; " ") | .[0:120])
                    else
                        .title
                    end
                )
                | .turns += (
                    if (
                        $item.type == "user"
                        and ($item.isMeta != true)
                        and ((($item.message.content // "") | tostring | startswith("<local-command-caveat>")) | not)
                        and ((($item.message.content // "") | tostring | startswith("<command-name>")) | not)
                    ) then 1 else 0 end
                )
                | if $item.type == "assistant" and ($item.message.usage? != null) then
                    .tokens += (
                        ($item.message.usage.input_tokens // 0)
                        + ($item.message.usage.cache_creation_input_tokens // 0)
                        + ($item.message.usage.cache_read_input_tokens // 0)
                        + ($item.message.usage.output_tokens // 0)
                    )
                    | .has_tokens = true
                else
                    .
                end
            )
            | [
                (.turns | tostring),
                (if .has_tokens then (.tokens | tostring) else "" end),
                .title
            ]
            | @tsv
        ' "$file" 2>/dev/null)
        IFS=$'\t' read -r turns tokens title <<< "$summary"
        [[ -z "$title" ]] && title="(no title)"
        [[ -n "$turns" ]] || turns="-"
        token_display=$(_format_session_tokens "$tokens")

        if (( $+builtins[zstat] )); then
            zstat -H st -- "$file" 2>/dev/null
            mtime=${st[mtime]:-0}
        else
            mtime=$(stat -f "%m" "$file" 2>/dev/null)
        fi
        if (( $+builtins[strftime] )); then
            strftime -s date_str "%m/%d %H:%M" "$mtime"
        else
            date_str=$(date -r "$mtime" "+%m/%d %H:%M")
        fi

        printf "%s\tclaude\t%s\t%s\t%s\t%s\t%s\t%s\n" "$mtime" "$date_str" "$turns" "$token_display" "$title" "$name" "$file"
    done
}

# Collect Codex sessions for current directory.
# Pre-filters candidates with ripgrep (or head+grep fallback) so we only run jq
# on files whose first line already contains the current cwd. Avoids scanning
# all ~/.codex/sessions/**/*.jsonl with jq, which is the dominant cost.
_collect_codex_sessions() {
    local codex_sessions_dir="$HOME/.codex/sessions"
    [[ -d "$codex_sessions_dir" ]] || return 0

    local current_path="$(pwd)"
    local needle="\"cwd\":\"$current_path\""
    local -a candidates

    if (( $+commands[rg] )); then
        candidates=("${(@f)$(rg -l --fixed-strings -- "$needle" \
            --glob '*.jsonl' "$codex_sessions_dir" 2>/dev/null)}")
    else
        local f
        while IFS= read -r -d '' f; do
            head -1 "$f" 2>/dev/null | grep -Fq -- "$needle" && candidates+=("$f")
        done < <(find "$codex_sessions_dir" -name '*.jsonl' -print0 2>/dev/null)
    fi

    zmodload -F zsh/stat b:zstat 2>/dev/null
    zmodload -F zsh/datetime b:strftime 2>/dev/null

    local file meta session_id title turns tokens token_display mtime date_str
    local -A st
    for file in $candidates; do
        [[ -f "$file" ]] || continue
        if (( $+builtins[zstat] )); then
            zstat -H st -- "$file" 2>/dev/null
            mtime=${st[mtime]:-0}
        else
            mtime=$(stat -f "%m" "$file" 2>/dev/null)
        fi
        if (( $+builtins[strftime] )); then
            strftime -s date_str "%m/%d %H:%M" "$mtime"
        else
            date_str=$(date -r "$mtime" "+%m/%d %H:%M")
        fi

        meta=$(jq -r -n --arg current_path "$current_path" '
            def user_title($item):
                if $item.type == "event_msg" and $item.payload.type == "user_message" then
                    ($item.payload.message // empty)
                elif $item.type == "response_item" and $item.payload.type == "message" and $item.payload.role == "user" then
                    $item.payload.content[]?
                    | select(.type == "input_text")
                    | .text
                    | select(
                        (startswith("# AGENTS.md instructions") | not)
                        and (startswith("<environment_context>") | not)
                        and (contains("<INSTRUCTIONS>") | not)
                    )
                else
                    empty
                end;

            reduce inputs as $item (
                {cwd: "", session_id: "", title: "", turns: 0, tokens: ""};
                if $item.type == "session_meta" then
                    .cwd = ($item.payload.cwd // "")
                    | .session_id = ($item.payload.id // "")
                else
                    .
                end
                | .title = (
                    if .title == "" then
                        (([user_title($item)] | .[0] // "") | gsub("[[:space:]]+"; " ") | .[0:120])
                    else
                        .title
                    end
                )
                | .turns += (
                    if $item.type == "event_msg" and $item.payload.type == "user_message" then 1 else 0 end
                )
                | if $item.type == "event_msg" and $item.payload.type == "token_count" and ($item.payload.info.total_token_usage.total_tokens? != null) then
                    .tokens = ($item.payload.info.total_token_usage.total_tokens | tostring)
                else
                    .
                end
            )
            | select(.cwd == $current_path and .session_id != "")
            | [.session_id, (.turns | tostring), .tokens, .title]
            | @tsv
        ' "$file" 2>/dev/null)
        [[ -z "$meta" ]] && continue
        IFS=$'\t' read -r session_id turns tokens title <<< "$meta"
        [[ -z "$title" ]] && title="(codex session)"
        [[ -n "$turns" ]] || turns="-"
        token_display=$(_format_session_tokens "$tokens")

        printf "%s\tcodex\t%s\t%s\t%s\t%s\t%s\t%s\n" "$mtime" "$date_str" "$turns" "$token_display" "$title" "$session_id" "$file"
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
        --with-nth=1,2,3,4,5,6 \
        --preview='
            tool=$(echo {} | awk -F"\t" "{print \$1}")
            filepath=$(echo {} | awk -F"\t" "{print \$7}")
            if [ "$tool" = "claude" ]; then
                head -200 "$filepath" 2>/dev/null | jq -r "select(.type==\"user\") | .message.content" 2>/dev/null | head -30
            else
                head -200 "$filepath" 2>/dev/null | jq -r "(select(.type==\"event_msg\" and .payload.type==\"user_message\") | .payload.message), (select(.type==\"response_item\" and .payload.type==\"message\" and .payload.role==\"user\") | .payload.content[]? | select(.type==\"input_text\") | .text | select((startswith(\"# AGENTS.md instructions\") | not) and (startswith(\"<environment_context>\") | not) and (contains(\"<INSTRUCTIONS>\") | not)))" 2>/dev/null | grep -v "^$" | awk "!seen[\$0]++" | head -30
            fi
        ' \
        --preview-window=right:40%:wrap)

    if [[ -n "$selected" ]]; then
        local tool=$(echo "$selected" | awk -F'\t' '{print $1}')
        local session_id=$(echo "$selected" | awk -F'\t' '{print $6}')
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
# fzf-session-resume forks head+jq per session file (~100s), which made
# the previous Ctrl-L binding feel >1s slow before fzf appeared.
bindkey '^K' fzf-session-resume
bindkey '^L' clear-screen
