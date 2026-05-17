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

_session_resume_limit() {
    local limit="${FZF_SESSION_RESUME_LIMIT:-50}"
    if [[ ! "$limit" =~ '^[1-9][0-9]*$' ]]; then
        echo "Error: FZF_SESSION_RESUME_LIMIT must be a positive integer" >&2
        return 1
    fi

    printf "%s" "$limit"
}

# Collect Claude Code sessions for current directory.
# Reads only recent files and only enough leading lines to build the fzf list.
_collect_claude_sessions() {
    local limit="$1"
    local claude_projects_dir="$HOME/.claude/projects"
    local current_path="$(pwd)"
    local current_dir="${current_path//\//-}"
    current_dir="${current_dir//./-}"
    current_dir="${current_dir#-}"
    local project_dir="$claude_projects_dir/-$current_dir"

    [[ -d "$project_dir" ]] || return 0

    zmodload -F zsh/stat b:zstat 2>/dev/null
    zmodload -F zsh/datetime b:strftime 2>/dev/null

    local file="" name="" title="" turns="" token_display="" mtime="" date_str="" count=0
    local -a files
    local -A st
    files=("$project_dir"/*.jsonl(Nom))
    for file in "${files[@]}"; do
        name="${${file:t}%.jsonl}"
        [[ "$name" == agent-* ]] && continue
        [[ ${#name} -ne 36 ]] && continue
        ((count++))
        ((count > limit)) && break

        title=$(head -200 "$file" 2>/dev/null | jq -r '
            select((.summary? // "") != "")
            | .summary
            | gsub("[[:space:]]+"; " ")
            | .[0:120]
        ' 2>/dev/null | head -1)
        [[ -z "$title" ]] && title="(no title)"
        turns="-"
        token_display="-"

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
# Pre-filters candidates with ripgrep, ranks them by mtime, then reads only
# enough leading lines from recent files to build the fzf list.
_collect_codex_sessions() {
    local limit="$1"
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

    local file="" meta="" session_id="" title="" turns="" token_display="" mtime="" date_str="" ranked=""
    local -A st
    ranked=$(
        for file in "${candidates[@]}"; do
            [[ -f "$file" ]] || continue
            if (( $+builtins[zstat] )); then
                zstat -H st -- "$file" 2>/dev/null
                mtime=${st[mtime]:-0}
            else
                mtime=$(stat -f "%m" "$file" 2>/dev/null)
            fi
            printf "%s\t%s\n" "$mtime" "$file"
        done | sort -t$'\t' -k1,1nr | head -n "$limit"
    )

    while IFS=$'\t' read -r mtime file; do
        [[ -n "$file" ]] || continue
        [[ -f "$file" ]] || continue
        if (( $+builtins[strftime] )); then
            strftime -s date_str "%m/%d %H:%M" "$mtime"
        else
            date_str=$(date -r "$mtime" "+%m/%d %H:%M")
        fi

        meta=$(head -200 "$file" 2>/dev/null | jq -r -n --arg current_path "$current_path" '
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
                {cwd: "", session_id: "", title: ""};
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
            )
            | select(.cwd == $current_path and .session_id != "")
            | [.session_id, .title]
            | @tsv
        ' 2>/dev/null)
        [[ -z "$meta" ]] && continue
        IFS=$'\t' read -r session_id title <<< "$meta"
        [[ -z "$title" ]] && title="(codex session)"
        turns="-"
        token_display="-"

        printf "%s\tcodex\t%s\t%s\t%s\t%s\t%s\t%s\n" "$mtime" "$date_str" "$turns" "$token_display" "$title" "$session_id" "$file"
    done <<< "$ranked"
}

# fzf session resume: Claude Code + Codex (current directory only)
function fzf-session-resume() {
    local session_limit
    if ! session_limit=$(_session_resume_limit); then
        zle -M "Invalid FZF_SESSION_RESUME_LIMIT"
        return 1
    fi

    local sessions=$(
        { _collect_claude_sessions "$session_limit"; _collect_codex_sessions "$session_limit" } | sort -t$'\t' -k1 -nr | cut -f2-
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
        --with-nth=1,2,5,6 \
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
