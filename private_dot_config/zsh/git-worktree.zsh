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

# Helper function to trust mise config files in the current worktree
_gw_trust_mise() {
    if command -v mise >/dev/null 2>&1; then
        mise trust --all >/dev/null 2>&1 || true
    fi
}

# Helper function to refresh Codex trusted projects after creating a worktree
_gw_refresh_codex_trust() {
    if ! command -v chezmoi >/dev/null 2>&1; then
        echo "Error: chezmoi not found; cannot refresh Codex trusted projects" >&2
        return 1
    fi

    echo "Refreshing Codex trusted projects..."
    chezmoi apply "$HOME/.codex/config.toml"
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
    local original_root=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
    if [ "$git_root" != "$original_root" ]; then
        echo "Currently in worktree. Switching to main repository: $original_root"
        cd "$original_root"
        git_root="$original_root"
    fi

    local repo_name=$(basename "$git_root")
    local worktree_base="${git_root}-worktree"

    # Determine base branch (prefer staging, fallback to main)
    local base_branch="staging"
    if ! git show-ref --verify --quiet "refs/heads/$base_branch" && \
       ! git show-ref --verify --quiet "refs/remotes/origin/$base_branch"; then
        base_branch="main"
    fi

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

    local worktree_dir="${worktree_base}/${branch_name//\//-}"

    if git worktree list | grep -qF "$worktree_dir"; then
        echo "Worktree already exists at: $worktree_dir"
        echo "Changing directory to existing worktree..."
        cd "$worktree_dir"

        _gw_copy_env "$git_root"
        _gw_setup_direnv
        return 0
    fi

    # Fetch all latest remote refs
    echo "Fetching latest from origin..."
    if ! git fetch origin; then
        echo "Error: Failed to fetch from remote"
        return 1
    fi

    # Update base branch to latest remote
    echo "Updating $base_branch branch to latest remote..."

    if ! git show-ref --verify --quiet "refs/heads/$base_branch"; then
        if ! git branch "$base_branch" "origin/$base_branch"; then
            echo "Error: Failed to create local $base_branch branch"
            return 1
        fi
    else
        local staging_worktree=$(git worktree list --porcelain | awk '/^worktree/ {wt=$2} /^branch refs\/heads\/'"$base_branch"'$/ {print wt; exit}')
        if [ -n "$staging_worktree" ]; then
            echo "Updating $base_branch in worktree: $staging_worktree"
            if ! (cd "$staging_worktree" && git pull origin "$base_branch"); then
                echo "Error: Failed to update $base_branch in worktree"
                echo "Local changes detected in $staging_worktree"
                echo -n "Stash changes and retry? [Y/n]: "
                read -r stash_answer
                stash_answer=${stash_answer:-Y}
                if [[ "$stash_answer" =~ ^[Yy]$ ]]; then
                    if (cd "$staging_worktree" && git stash push -m "gw: auto-stash before updating $base_branch"); then
                        echo "Changes stashed. Retrying pull..."
                        if ! (cd "$staging_worktree" && git pull origin "$base_branch"); then
                            echo "Error: Still failed to update $base_branch"
                            echo "Restoring stashed changes..."
                            (cd "$staging_worktree" && git stash pop)
                            return 1
                        fi
                        echo "Successfully updated. Your changes are stashed (use 'git stash pop' to restore)"
                    else
                        echo "Error: Failed to stash changes"
                        return 1
                    fi
                else
                    echo "Aborted. Please commit or stash your changes manually in $staging_worktree"
                    return 1
                fi
            fi
        else
            if ! git branch -f "$base_branch" "origin/$base_branch"; then
                echo "Error: Failed to update local $base_branch branch"
                return 1
            fi
        fi
    fi

    local new_worktree_created=false

    local branch_worktree=$(git worktree list --porcelain | awk '/^worktree/ {wt=$2} /^branch refs\/heads\/'"$branch_name"'$/ {print wt; exit}')
    if [ -n "$branch_worktree" ]; then
        if [ "$branch_worktree" = "$git_root" ]; then
            echo "Branch '$branch_name' is checked out in main repository. Switching to $base_branch..."
            if ! git checkout "$base_branch"; then
                echo "Error: Failed to switch to $base_branch"
                return 1
            fi
        else
            echo "Branch '$branch_name' is already checked out in worktree: $branch_worktree"
            echo "Changing directory to existing worktree..."
            cd "$branch_worktree"

            _gw_copy_env "$git_root"
            _gw_setup_direnv

            return 0
        fi
    fi

    if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
        if git show-ref --verify --quiet "refs/heads/$branch_name"; then
            echo "Deleting local branch to sync with remote: $branch_name"
            git branch -D "$branch_name"
        fi
        echo "Creating worktree for remote branch: $branch_name"
        if ! git worktree add "$worktree_dir" "$branch_name"; then
            echo "Error: Failed to create worktree for branch $branch_name"
            return 1
        fi
        cd "$worktree_dir"
        new_worktree_created=true
    elif git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo "Creating worktree for local-only branch: $branch_name"
        if ! git worktree add "$worktree_dir" "$branch_name"; then
            echo "Error: Failed to create worktree for branch $branch_name"
            return 1
        fi
        cd "$worktree_dir"
        new_worktree_created=true
    else
        echo "Creating new branch '$branch_name' from $base_branch and worktree"
        if ! git worktree add -b "$branch_name" "$worktree_dir" "$base_branch"; then
            echo "Error: Failed to create new branch and worktree"
            return 1
        fi
        cd "$worktree_dir"
        new_worktree_created=true
    fi

    if [ "$new_worktree_created" = true ]; then
        _gw_copy_env "$git_root"
        _gw_setup_direnv
        _gw_trust_mise
        _gw_refresh_codex_trust || return 1

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
    fi
}

# AI-assisted worktree creation: prompt -> branch name (via claude haiku) -> gw -> session
# Usage:
#   gwai <prompt>          # generate branch name and start `cl` session with the prompt
#   gwai -c <prompt>       # explicit claude
#   gwai -x <prompt>       # explicit codex (cdx)
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
EOF
            return 1
            ;;
    esac

    local prompt="$*"
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
    local naming_prompt branch_name
    naming_prompt="Generate exactly one git branch name for the task below.
Rules:
- Prefix with one of: feat/, fix/, refactor/, docs/, test/, chore/, perf/
- After the prefix, kebab-case, ASCII only, 3-7 words.
- Output ONLY the branch name. No quotes, no commentary, no trailing punctuation.

Task: ${prompt}"

    branch_name=$(claude -p --model haiku "$naming_prompt" 2>/dev/null \
        | tr -d '\r`"'\''' \
        | awk 'NF{print; exit}' \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

    if [[ -z "$branch_name" ]]; then
        echo "Error: branch name generation returned empty output" >&2
        return 1
    fi
    if [[ ! "$branch_name" =~ ^(feat|fix|refactor|docs|test|chore|perf)/[a-z0-9][a-z0-9-]*$ ]]; then
        echo "Error: generated branch name is invalid: '$branch_name'" >&2
        return 1
    fi

    echo "🌿 Branch:   $branch_name"
    echo "🚀 Launcher: $launcher"

    gw "$branch_name" || return 1

    "$launcher" "$prompt"
}

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

# Git worktree cleanup function
function gwc() {
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

    local selected_lines=$(echo "$worktrees" | sed 's/\[//g; s/\]//g' | fzf \
        -m \
        --height=60% \
        --reverse \
        --prompt="削除するworktreeを選択 (Tab: 複数選択): " \
        --header="新しい作成日順 | Tab: 選択/解除, Enter: 確定" \
        --preview="$(_gw_worktree_fzf_preview_command)" \
        --preview-window='right:55%:wrap')

    if [ -z "$selected_lines" ]; then
        echo "worktreeが選択されませんでした"
        return 1
    fi

    local -a worktree_paths
    local -a branch_names
    while IFS= read -r line; do
        local selected_path=$(echo "$line" | awk '{print $1}')
        local selected_branch

        if selected_branch=$(git -C "$selected_path" symbolic-ref --short HEAD 2>/dev/null); then
            :
        elif git -C "$selected_path" rev-parse --verify HEAD >/dev/null 2>&1; then
            selected_branch="(detached HEAD)"
        else
            echo "Error: failed to read branch for worktree: $selected_path" >&2
            return 1
        fi

        worktree_paths+=("$selected_path")
        branch_names+=("$selected_branch")
    done <<< "$selected_lines"

    echo "削除予定のworktree (${#worktree_paths[@]}件):"
    for i in {1..${#worktree_paths[@]}}; do
        echo "  [$i] パス: ${worktree_paths[$i]}"
        echo "      ブランチ: ${branch_names[$i]}"
    done
    echo -n "本当に削除しますか？ (y/N): "
    read confirmation

    if [[ "$confirmation" =~ ^[yY]$ ]]; then
        local success_count=0
        local fail_count=0

        for i in {1..${#worktree_paths[@]}}; do
            local worktree_path="${worktree_paths[$i]}"
            local branch_name="${branch_names[$i]}"

            echo ""
            echo "[$i/${#worktree_paths[@]}] worktreeを削除中: $worktree_path"
            if git worktree remove "$worktree_path" --force; then
                echo "✅ worktreeが削除されました: $worktree_path"
                ((success_count++))

                if [ -d "$worktree_path" ]; then
                    echo "📂 残りのディレクトリを削除中..."
                    rm -rf "$worktree_path"
                fi

                _gwc_remove_claude_cache "$worktree_path"
            else
                echo "❌ worktreeの削除に失敗しました: $worktree_path"
                ((fail_count++))
            fi
        done

        echo ""
        echo "=========================================="
        echo "削除完了: 成功 $success_count 件, 失敗 $fail_count 件"
        echo "=========================================="

        if [ $fail_count -gt 0 ]; then
            return 1
        fi
    else
        echo "削除をキャンセルしました"
        return 0
    fi
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
