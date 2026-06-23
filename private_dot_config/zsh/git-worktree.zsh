#
# Git Worktree Management
#

# Helper function to handle direnv setup in worktree
_gw_setup_direnv() {
    if [ -f ".envrc" ] && command -v direnv >/dev/null 2>&1; then
        echo "Found .envrc file. Allowing direnv..."
        direnv allow
    fi
}

# Helper function to copy .env / .envrc from original repository
_gw_copy_env() {
    local original_git_root="$1"
    local file
    for file in .env .envrc; do
        if [ -f "$original_git_root/$file" ] && [ ! -f "$file" ]; then
            echo "Found $file in original repository. Copying to worktree..."
            cp "$original_git_root/$file" .
        fi
    done
}

_gw_worktree_created_at() {
    local worktree_path="$1"
    local created_at

    if [ ! -d "$worktree_path" ]; then
        echo "Error: worktree path does not exist: $worktree_path" >&2
        echo "Run 'git worktree prune' to remove stale worktree metadata." >&2
        return 1
    fi

    if created_at=$(stat -f "%B" "$worktree_path" 2>/dev/null); then
        if [[ "$created_at" =~ '^[0-9]+$' ]] && [ "$created_at" -gt 0 ]; then
            echo "$created_at"
            return 0
        fi

        echo "Error: creation time is unavailable for worktree: $worktree_path" >&2
        return 1
    fi

    if created_at=$(stat -c "%W" "$worktree_path" 2>/dev/null); then
        if [[ "$created_at" =~ '^[0-9]+$' ]] && [ "$created_at" -gt 0 ]; then
            echo "$created_at"
            return 0
        fi

        echo "Error: creation time is unavailable for worktree: $worktree_path" >&2
        return 1
    fi

    echo "Error: failed to read creation time for worktree: $worktree_path" >&2
    return 1
}

_gw_worktree_list_newest_first() {
    if [ "${1:-}" = "--prune-stale" ]; then
        if ! git worktree prune; then
            echo "Error: failed to prune stale worktree metadata" >&2
            return 1
        fi
    fi

    local line
    local worktree_path
    local created_at
    local -a entries

    while IFS= read -r line; do
        worktree_path="${line%%[[:space:]]*}"
        if ! created_at=$(_gw_worktree_created_at "$worktree_path"); then
            return 1
        fi

        entries+=("${created_at}"$'\t'"${line}")
    done < <(git worktree list)

    if [ ${#entries[@]} -gt 0 ]; then
        printf '%s\n' "${entries[@]}" | sort -rn -k1,1 | cut -f2-
    fi
}

_gw_worktree_fzf_preview_command() {
    cat <<'EOF'
worktree_path={1}

if [ -z "$worktree_path" ]; then
    exit 0
fi

if [ ! -d "$worktree_path" ]; then
    echo "Error: worktree path does not exist: $worktree_path" >&2
    exit 1
fi

if created_epoch=$(stat -f "%B" "$worktree_path" 2>/dev/null); then
    :
elif created_epoch=$(stat -c "%W" "$worktree_path" 2>/dev/null); then
    :
else
    echo "Error: failed to read creation time for worktree: $worktree_path" >&2
    exit 1
fi

if ! printf '%s\n' "$created_epoch" | grep -Eq '^[0-9]+$' || [ "$created_epoch" -le 0 ]; then
    echo "Error: creation time is unavailable for worktree: $worktree_path" >&2
    exit 1
fi

if created_at=$(date -r "$created_epoch" "+%Y-%m-%d %H:%M:%S" 2>/dev/null); then
    :
elif created_at=$(date -d "@$created_epoch" "+%Y-%m-%d %H:%M:%S" 2>/dev/null); then
    :
else
    echo "Error: failed to format creation time for worktree: $worktree_path" >&2
    exit 1
fi

commit=$(git -C "$worktree_path" rev-parse --short HEAD) || exit 1
subject=$(git -C "$worktree_path" log -1 --format=%s) || exit 1
branch=$(git -C "$worktree_path" symbolic-ref --short HEAD 2>/dev/null)
if [ -z "$branch" ]; then
    branch="(detached HEAD)"
fi

status_lines=$(git -C "$worktree_path" status --short) || exit 1
if [ -n "$status_lines" ]; then
    state="dirty"
else
    state="clean"
fi

printf '%s\n' "Worktree details"
printf '%s\n' "----------------"
printf 'Path:     %s\n' "$worktree_path"
printf 'Branch:   %s\n' "$branch"
printf 'Commit:   %s %s\n' "$commit" "$subject"
printf 'Created:  %s\n' "$created_at"
printf 'State:    %s\n' "$state"

if upstream=$(git -C "$worktree_path" rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null); then
    ahead_behind=$(git -C "$worktree_path" rev-list --left-right --count "$upstream...HEAD") || exit 1
    behind=$(printf '%s\n' "$ahead_behind" | awk '{print $1}')
    ahead=$(printf '%s\n' "$ahead_behind" | awk '{print $2}')
    printf 'Upstream: %s (ahead %s, behind %s)\n' "$upstream" "$ahead" "$behind"
else
    printf '%s\n' "Upstream: not configured"
fi

printf '\n%s\n' "Status"
printf '%s\n' "------"
git -C "$worktree_path" status --short --branch

printf '\n%s\n' "Recent commits"
printf '%s\n' "--------------"
git -C "$worktree_path" log --oneline --decorate -5
EOF
}

_gw_write_vscode_workspace() {
    local worktree_dir="$1"
    local repo_name="$2"
    local branch_name="$3"

    local colors=(
        "#e74c3c" "#3498db" "#2ecc71" "#f39c12" "#9b59b6"
        "#1abc9c" "#e91e63" "#ff5722" "#607d8b" "#795548"
        "#ff9800" "#4caf50" "#00bcd4" "#673ab7" "#009688"
        "#8bc34a" "#ffc107" "#03a9f4" "#ff6f00" "#7b1fa2"
        "#00695c" "#c2185b" "#1976d2" "#388e3c"
    )
    local color_index=$(( $(echo "$branch_name" | cksum | cut -d' ' -f1) % ${#colors[@]} ))
    local color="${colors[$color_index]}"

    local workspace_file="${worktree_dir}/worktree.code-workspace"
    cat > "$workspace_file" << EOF
{
  "folders": [
    {
      "path": "."
    }
  ],
  "settings": {
    "window.title": "${repo_name}:${branch_name}",
    "workbench.colorCustomizations": {
      "titleBar.activeBackground": "$color",
      "titleBar.activeForeground": "#fff"
    }
  }
}
EOF

    local exclude_file=".git/info/exclude"
    if [ -f "$exclude_file" ]; then
        if ! grep -q "^worktree\.code-workspace$" "$exclude_file"; then
            echo "worktree.code-workspace" >> "$exclude_file"
        fi
    fi

    echo "🎨 Branch: $branch_name | Color: $color"
}

_gw_create_worktree() {
    local branch_name="$1"
    local creation_output output_file helper_status tee_status
    local -a pipeline_status

    if ! command -v gw-create-worktree >/dev/null 2>&1; then
        echo "Error: gw-create-worktree not found in PATH" >&2
        return 1
    fi

    output_file=$(mktemp) || return 1

    gw-create-worktree "$branch_name" | tee "$output_file"
    pipeline_status=("${pipestatus[@]}")
    helper_status="${pipeline_status[1]}"
    tee_status="${pipeline_status[2]}"

    if ! creation_output=$(cat "$output_file"); then
        rm -f "$output_file"
        return 1
    fi
    rm -f "$output_file"

    if [ "$tee_status" -ne 0 ]; then
        echo "Error: failed to capture gw-create-worktree output" >&2
        return "$tee_status"
    fi

    if [ "$helper_status" -ne 0 ]; then
        return "$helper_status"
    fi

    _GW_CREATED_PATH=$(printf '%s\n' "$creation_output" | awk -F= '$1 == "WORKTREE_PATH" {print substr($0, index($0, "=") + 1)}' | tail -1)
    _GW_CREATED_FLAG=$(printf '%s\n' "$creation_output" | awk -F= '$1 == "WORKTREE_CREATED" {print $2}' | tail -1)

    if [ -z "$_GW_CREATED_PATH" ]; then
        echo "Error: gw-create-worktree did not output WORKTREE_PATH" >&2
        return 1
    fi
}

# Smart git worktree function for InsightX
function gw() {
    local branch_name=$1
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)

    # Check if we're in a git repository
    if [ -z "$git_root" ]; then
        echo "Error: not a git repository"
        return 1
    fi

    # Resolve to the main (non-worktree) repository root
    local original_root=$(git worktree list --porcelain | awk 'NR == 1 { sub(/^worktree /, ""); print }')
    if [ -z "$original_root" ]; then
        echo "Error: failed to resolve main worktree root." >&2
        return 1
    fi
    if [ "$git_root" != "$original_root" ]; then
        echo "Currently in worktree. Switching to main repository: $original_root"
        cd "$original_root"
        git_root="$original_root"
    fi

    local repo_name=$(basename "$git_root")

    if [ -z "$branch_name" ]; then
        local worktree_list
        if ! worktree_list=$(_gw_worktree_list_newest_first); then
            return 1
        fi

        local selected_worktree=$(printf '%s\n' "$worktree_list" | fzf --height=60% --reverse --preview="$(_gw_worktree_fzf_preview_command)" --preview-window='right:55%:wrap' | awk '{print $1}')
        if [ -n "$selected_worktree" ]; then
            echo "Moving to worktree: $selected_worktree"
            cd "$selected_worktree"

            _gw_copy_env "$git_root"
            _gw_setup_direnv

            return 0
        else
            echo "No worktree selected"
            return 1
        fi
    fi

    if ! _gw_create_worktree "$branch_name"; then
        return 1
    fi

    echo "Changing directory to worktree: $_GW_CREATED_PATH"
    cd "$_GW_CREATED_PATH" || return 1
    _gw_copy_env "$git_root"
    _gw_setup_direnv

    if [ "$_GW_CREATED_FLAG" = "1" ]; then
        _gw_write_vscode_workspace "$_GW_CREATED_PATH" "$repo_name" "$branch_name"
    fi
}

# AI-assisted worktree creation: prompt -> branch name (via claude haiku) -> gw -> session
# Usage:
#   gwai <prompt>          # generate branch name and start `cl` session with the prompt
#   gwai -c <prompt>       # explicit claude
#   gwai -x <prompt>       # explicit codex (cdx)
#   pbpaste | gwai -x <prompt>
function gwai() {
    local launcher="cl"
    case "${1:-}" in
        -c) launcher="cl"; shift ;;
        -x) launcher="cdx"; shift ;;
        -h|--help|"")
            cat <<'EOF'
Usage: gwai [-c|-x] <prompt>
  -c   start claude session via `cl` (default)
  -x   start codex session via `cdx`

Generates a Conventional Commits style branch name from <prompt>
using `claude -p --model haiku`, creates a worktree via `gw`,
then launches the chosen session with <prompt> as the first message.

If stdin is piped, stdin is appended to <prompt>.
EOF
            return 1
            ;;
    esac

    local prompt="$*"
    if [[ ! -t 0 ]]; then
        local stdin_prompt
        stdin_prompt=$(cat)
        if [[ -n "$stdin_prompt" ]]; then
            if [[ -n "$prompt" ]]; then
                prompt="${prompt}
${stdin_prompt}"
            else
                prompt="$stdin_prompt"
            fi
        fi
    fi

    if [ -z "$prompt" ]; then
        echo "Error: prompt is empty" >&2
        return 1
    fi

    if ! command -v claude >/dev/null 2>&1; then
        echo "Error: claude CLI not found in PATH" >&2
        return 1
    fi
    if ! command -v "$launcher" >/dev/null 2>&1 && ! typeset -f "$launcher" >/dev/null; then
        echo "Error: launcher '$launcher' not found" >&2
        return 1
    fi

    echo "🤖 Generating branch name with claude haiku..."
    local naming_prompt naming_output branch_type branch_slug branch_name
    naming_prompt="Generate exactly one git branch type and slug for the task below.
Rules:
- Output exactly two tokens separated by one space: <type> <slug>
- <type> must be one of: feat, fix, refactor, docs, test, chore, perf
- <slug> must be kebab-case, ASCII only, 3-7 words.
- Do not include the type in <slug>. The shell function prefixes it.
- Output ONLY the two tokens. No quotes, no commentary, no trailing punctuation.

Task: ${prompt}"

    naming_output=$(claude -p --model haiku "$naming_prompt" 2>/dev/null \
        | tr -d '\r`"'\''' \
        | awk 'NF{print; exit}' \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    if [[ -z "$naming_output" ]]; then
        echo "Error: branch name generation returned empty output" >&2
        return 1
    fi

    branch_type=$(printf '%s\n' "$naming_output" | awk '{print $1}')
    branch_slug=$(printf '%s\n' "$naming_output" | awk '{print $2}')

    if [[ "$naming_output" = "$branch_type $branch_slug" ]] \
        && [[ "$branch_type" =~ ^(feat|fix|refactor|docs|test|chore|perf)$ ]] \
        && [[ "$branch_slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        branch_name="${branch_type}-${branch_slug}"
    else
        local fallback_stamp
        if ! fallback_stamp=$(date "+%Y%m%d%H%M%S"); then
            echo "Error: failed to generate fallback branch timestamp" >&2
            return 1
        fi
        branch_name="chore-ai-task-${fallback_stamp}"
        echo "Warning: generated branch components are invalid, using rough branch name: '$branch_name'" >&2
        echo "Invalid generation output: '$naming_output'" >&2
    fi

    if [[ ! "$branch_name" =~ ^(feat|fix|refactor|docs|test|chore|perf)-[a-z0-9][a-z0-9-]*$ ]]; then
        echo "Error: generated branch name is invalid: '$branch_name'" >&2
        return 1
    fi

    echo "🌿 Branch:   $branch_name"
    echo "🚀 Launcher: $launcher"

    local current_git_root current_dir_name
    if current_git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
        current_dir_name=$(basename "$current_git_root")
        if [[ "$current_dir_name" = "$branch_name" ]]; then
            echo "Using current directory: $current_git_root"
            "$launcher" "$prompt"
            return
        fi
    fi

    gw "$branch_name" || return 1

    "$launcher" "$prompt"
}
alias gwai='noglob gwai'

# Helper function to remove Claude Code cache for a worktree path
_gwc_remove_claude_cache() {
    local worktree_path="$1"
    local claude_projects_dir="$HOME/.claude/projects"

    local cache_dir_name="${worktree_path//\//-}"
    cache_dir_name="${cache_dir_name//./-}"
    cache_dir_name="${cache_dir_name#-}"
    local claude_cache_path="$claude_projects_dir/-$cache_dir_name"

    if [ -d "$claude_cache_path" ]; then
        echo "🗑️  Claude Codeのキャッシュを削除中: $claude_cache_path"
        rm -rf "$claude_cache_path"
        echo "✅ Claude Codeのキャッシュを削除しました"
        return 0
    else
        echo "ℹ️  Claude Codeのキャッシュは見つかりませんでした"
        return 1
    fi
}

_gwc_remove_worktree() {
    local index="$1"
    local total="$2"
    local worktree_path="$3"

    echo ""
    echo "[$index/$total] worktreeを削除中: $worktree_path"
    if git worktree remove "$worktree_path" --force; then
        echo "✅ worktreeが削除されました: $worktree_path"

        if [ -d "$worktree_path" ]; then
            echo "📂 残りのディレクトリを削除中..."
            rm -rf "$worktree_path"
        fi

        _gwc_remove_claude_cache "$worktree_path" || true
        return 0
    fi

    echo "❌ worktreeの削除に失敗しました: $worktree_path"
    return 1
}

_gwc_select_worktrees() {
    local worktrees="$1"

    echo "$worktrees" | sed 's/\[//g; s/\]//g' | fzf \
        -m \
        --height=60% \
        --reverse \
        --prompt="削除するworktreeを選択 (Tab: 複数選択): " \
        --header="新しい作成日順 | Tab: 選択/解除, Enter: 確定" \
        --preview="$(_gw_worktree_fzf_preview_command)" \
        --preview-window='right:55%:wrap'
}

_gwc_collect_selected_worktrees() {
    local selected_lines="$1"
    local line
    local selected_path
    local selected_branch

    _GWC_WORKTREE_PATHS=()
    _GWC_BRANCH_NAMES=()

    while IFS= read -r line; do
        selected_path=$(echo "$line" | awk '{print $1}')

        if selected_branch=$(git -C "$selected_path" symbolic-ref --short HEAD 2>/dev/null); then
            :
        elif git -C "$selected_path" rev-parse --verify HEAD >/dev/null 2>&1; then
            selected_branch="(detached HEAD)"
        else
            echo "Error: failed to read branch for worktree: $selected_path" >&2
            return 1
        fi

        _GWC_WORKTREE_PATHS+=("$selected_path")
        _GWC_BRANCH_NAMES+=("$selected_branch")
    done <<< "$selected_lines"
}

_gwc_confirm_removal() {
    echo "削除予定のworktree (${#_GWC_WORKTREE_PATHS[@]}件):"
    local i=1
    while [ "$i" -le "${#_GWC_WORKTREE_PATHS[@]}" ]; do
        echo "  [$i] パス: ${_GWC_WORKTREE_PATHS[$i]}"
        echo "      ブランチ: ${_GWC_BRANCH_NAMES[$i]}"
        ((i++))
    done
    echo -n "本当に削除しますか？ (y/N): "

    local confirmation
    read confirmation
    [[ "$confirmation" =~ ^[yY]$ ]]
}

_gwc_remove_selected_worktrees() {
    local max_jobs="$1"
    local success_count=0
    local fail_count=0
    local total=${#_GWC_WORKTREE_PATHS[@]}
    local tmp_dir
    local -a pids
    local -a log_files

    if ! tmp_dir=$(mktemp -d); then
        echo "Error: failed to create temporary directory for gwc logs" >&2
        return 1
    fi

    echo ""
    echo "並列削除を開始します: 最大 $max_jobs 件"

    local i=1
    local active_count=0
    local next_wait_index=1
    while [ "$i" -le "$total" ]; do
        local worktree_path="${_GWC_WORKTREE_PATHS[$i]}"
        local log_file="$tmp_dir/$i.log"

        log_files[$i]="$log_file"
        _gwc_remove_worktree "$i" "$total" "$worktree_path" > "$log_file" 2>&1 &
        pids[$i]="$!"
        ((active_count++))

        if [ "$active_count" -ge "$max_jobs" ]; then
            if wait "${pids[$next_wait_index]}"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
            ((active_count--))
            ((next_wait_index++))
        fi

        ((i++))
    done

    while [ "$next_wait_index" -le "$total" ]; do
        if wait "${pids[$next_wait_index]}"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        ((next_wait_index++))
    done

    i=1
    while [ "$i" -le "$total" ]; do
        cat "${log_files[$i]}"
        ((i++))
    done
    rm -rf "$tmp_dir"

    echo ""
    echo "=========================================="
    echo "削除完了: 成功 $success_count 件, 失敗 $fail_count 件"
    echo "=========================================="

    if [ $fail_count -gt 0 ]; then
        return 1
    fi
}

# Git worktree cleanup function
function gwc() {
    local max_jobs=4
    while [ $# -gt 0 ]; do
        case "$1" in
            -j|--jobs)
                shift
                if [[ -z "${1:-}" || ! "$1" =~ '^[1-9][0-9]*$' ]]; then
                    echo "Error: -j/--jobs requires a positive integer" >&2
                    return 1
                fi
                max_jobs="$1"
                ;;
            -h|--help)
                cat <<'EOF'
Usage: gwc [-j jobs]

Remove selected git worktrees in parallel.

Options:
  -j, --jobs <n>  Maximum parallel deletions (default: 4)
  -h, --help      Show this help
EOF
                return 0
                ;;
            *)
                echo "Error: unknown option: $1" >&2
                return 1
                ;;
        esac
        shift
    done

    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    local repo_name=$(basename "$git_root")
    local worktree_base="${git_root}-worktree"
    local worktree_list

    if ! worktree_list=$(_gw_worktree_list_newest_first --prune-stale); then
        return 1
    fi

    local worktrees=$(printf '%s\n' "$worktree_list" | awk -v current_root="$(git rev-parse --show-toplevel)" '$1 != current_root')

    if [ -z "$worktrees" ]; then
        echo "削除可能なworktreeが見つかりません"
        return 1
    fi

    local selected_lines
    selected_lines=$(_gwc_select_worktrees "$worktrees")

    if [ -z "$selected_lines" ]; then
        echo "worktreeが選択されませんでした"
        return 1
    fi

    if ! _gwc_collect_selected_worktrees "$selected_lines"; then
        return 1
    fi

    if ! _gwc_confirm_removal; then
        echo "削除をキャンセルしました"
        return 0
    fi

    _gwc_remove_selected_worktrees "$max_jobs"
}

# Git local branch cleanup function
function gbc() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: not a git repository"
        return 1
    fi

    local current_branch=$(git branch --show-current)

    git fetch --prune >/dev/null 2>&1

    local branches_with_status=""
    while read -r branch; do
        local status=""
        local has_local=true
        local has_remote=false

        if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            has_remote=true
        fi

        if [ "$has_local" = true ] && [ "$has_remote" = true ]; then
            status="[L+R]"
        else
            status="[L]  "
        fi

        branches_with_status+="${status} ${branch}"$'\n'
    done < <(git branch --format='%(refname:short)' | grep -v "^${current_branch}$")

    branches_with_status=$(echo "$branches_with_status" | sed '/^$/d')

    if [ -z "$branches_with_status" ]; then
        echo "削除可能なブランチがありません（現在のブランチ: $current_branch）"
        return 1
    fi

    local selected_lines=$(echo "$branches_with_status" | fzf \
        -m \
        --height=60% \
        --reverse \
        --prompt="削除するブランチを選択 (Tab: 複数選択): " \
        --header="現在のブランチ: $current_branch | [L]=Local only, [L+R]=Local+Remote | Tab: 選択/解除" \
        --preview='git log --oneline -10 $(echo {} | awk "{print \$2}")')

    if [ -z "$selected_lines" ]; then
        echo "ブランチが選択されませんでした"
        return 1
    fi

    local selected_branches=$(echo "$selected_lines" | awk '{print $2}')

    local branch_count=$(echo "$selected_branches" | wc -l | tr -d ' ')

    echo "削除予定のブランチ (${branch_count}件):"
    echo "$selected_lines" | while read -r line; do
        echo "  $line"
    done
    echo -n "本当に削除しますか？ (y/N): "
    read confirmation

    if [[ "$confirmation" =~ ^[yY]$ ]]; then
        local success_count=0
        local fail_count=0

        echo "$selected_branches" | while read -r branch; do
            echo ""
            echo "ブランチを削除中: $branch"
            if git branch -d "$branch" 2>/dev/null; then
                echo "✅ ブランチが削除されました: $branch"
                ((success_count++))
            elif git branch -D "$branch" 2>/dev/null; then
                echo "⚠️ ブランチを強制削除しました: $branch"
                ((success_count++))
            else
                echo "❌ ブランチの削除に失敗しました: $branch"
                ((fail_count++))
            fi
        done

        echo ""
        echo "=========================================="
        echo "削除完了"
        echo "=========================================="
    else
        echo "削除をキャンセルしました"
        return 0
    fi
}
