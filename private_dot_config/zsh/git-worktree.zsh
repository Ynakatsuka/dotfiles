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

# Helper function to open Cursor if available
_gw_open_cursor() {
    if command -v cursor >/dev/null 2>&1; then
        echo "Opening Cursor..."
        cursor .
    fi
}

# Helper function to copy .env file from original repository
_gw_copy_env() {
    local original_git_root="$1"

    if [ -f "$original_git_root/.env" ] && [ ! -f ".env" ]; then
        echo "Found .env file in original repository. Copying to worktree..."
        cp "$original_git_root/.env" .
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

    local repo_name=$(basename "$git_root")
    local worktree_base="${git_root}-worktree"

    # Determine base branch (prefer staging, fallback to main)
    local base_branch="staging"
    if ! git show-ref --verify --quiet "refs/heads/$base_branch" && \
       ! git show-ref --verify --quiet "refs/remotes/origin/$base_branch"; then
        base_branch="main"
    fi

    if [ -z "$branch_name" ]; then
        local selected_worktree=$(git worktree list | fzf --height=40% --reverse --preview='echo "Branch: $(basename $(echo {} | awk "{print \$1}"))"' | awk '{print $1}')
        if [ -n "$selected_worktree" ]; then
            echo "Moving to worktree: $selected_worktree"
            cd "$selected_worktree"

            _gw_copy_env "$git_root"
            _gw_setup_direnv
            _gw_open_cursor
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
        _gw_open_cursor
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
            _gw_open_cursor
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

        if command -v cursor >/dev/null 2>&1; then
            echo "Opening Cursor with workspace file..."
            cursor "$workspace_file"
        fi
    fi
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

    local worktrees=$(git worktree list | grep -v "$(git rev-parse --show-toplevel)$")

    if [ -z "$worktrees" ]; then
        echo "削除可能なworktreeが見つかりません"
        return 1
    fi

    local selected_lines=$(echo "$worktrees" | sed 's/\[//g; s/\]//g' | fzf \
        -m \
        --height=60% \
        --reverse \
        --prompt="削除するworktreeを選択 (Tab: 複数選択): " \
        --header="Tab: 選択/解除, Enter: 確定")

    if [ -z "$selected_lines" ]; then
        echo "worktreeが選択されませんでした"
        return 1
    fi

    local -a worktree_paths
    local -a branch_names
    while IFS= read -r line; do
        worktree_paths+=("$(echo "$line" | awk '{print $1}')")
        branch_names+=("$(echo "$line" | awk '{print $2}')")
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
