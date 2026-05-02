#!/usr/bin/env bash
# Create a git worktree, after fast-forwarding origin/{staging,main,master}.
#
# Usage: create-worktree.sh <branch_name>
#
# Conventions (match `gw` in private_dot_config/zsh/git-worktree.zsh):
#   - Worktree path: ${repo_root}-worktree/${branch_name//\//-}
#   - Base branch priority: staging > main > master (whichever exists on origin)
#   - .env / .envrc copied from main repo, direnv allow run if available
#
# Exit codes:
#   0  success
#   1  runtime error (non-git dir, fetch failure, divergence, etc.)
#   2  usage error

set -euo pipefail

branch_name="${1:-}"
if [[ -z "$branch_name" ]]; then
  echo "Usage: $0 <branch_name>" >&2
  exit 2
fi

refresh_codex_trust() {
  if ! command -v chezmoi >/dev/null 2>&1; then
    echo "Error: chezmoi not found; cannot refresh Codex trusted projects" >&2
    return 1
  fi

  echo "Refreshing Codex trusted projects..."
  chezmoi apply "$HOME/.codex/config.toml"
}

git_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not in a git repository" >&2
  exit 1
}

# Resolve to the main (non-worktree) repository root.
original_root="$(git worktree list --porcelain | head -1 | sed 's/^worktree //')"
if [[ "$git_root" != "$original_root" ]]; then
  echo "Currently in a worktree. Switching to main repository: $original_root"
  cd "$original_root"
  git_root="$original_root"
fi

worktree_base="${git_root}-worktree"
sanitized="${branch_name//\//-}"
worktree_dir="${worktree_base}/${sanitized}"

# Short-circuit: branch already has a worktree somewhere.
existing_wt="$(
  git worktree list --porcelain |
    awk -v b="$branch_name" '
      /^worktree/ { wt = $2 }
      $1 == "branch" && $2 == "refs/heads/" b { print wt; exit }
    '
)"
if [[ -n "$existing_wt" ]]; then
  echo "Worktree for '$branch_name' already exists at: $existing_wt"
  echo "WORKTREE_PATH=$existing_wt"
  exit 0
fi

if [[ -e "$worktree_dir" ]]; then
  echo "Error: '$worktree_dir' already exists but is not a registered worktree." >&2
  echo "Inspect and remove manually before retrying." >&2
  exit 1
fi

echo "Fetching from origin..."
git fetch origin --prune

# Fast-forward each base branch that exists on origin. Priority: staging > main > master.
base_candidates=(staging main master)
chosen_base=""

for b in "${base_candidates[@]}"; do
  if ! git show-ref --verify --quiet "refs/remotes/origin/$b"; then
    continue
  fi

  # Worktree (incl. main repo) where this branch is currently checked out.
  checked_out_at="$(
    git worktree list --porcelain |
      awk -v b="$b" '
        /^worktree/ { wt = $2 }
        $1 == "branch" && $2 == "refs/heads/" b { print wt; exit }
      '
  )"

  if [[ -n "$checked_out_at" ]]; then
    echo "Pulling '$b' (checked out at $checked_out_at)..."
    if ! git -C "$checked_out_at" pull --ff-only origin "$b"; then
      echo "Error: failed to fast-forward '$b' in $checked_out_at." >&2
      echo "Resolve uncommitted changes or divergence there, then retry." >&2
      exit 1
    fi
  elif git show-ref --verify --quiet "refs/heads/$b"; then
    echo "Fast-forwarding local '$b' to origin/$b..."
    if ! git fetch origin "$b:$b"; then
      echo "Error: local '$b' has diverged from origin/$b." >&2
      echo "Reconcile manually (rebase / reset), then retry." >&2
      exit 1
    fi
  else
    echo "Creating local '$b' from origin/$b..."
    git branch "$b" "origin/$b"
  fi

  if [[ -z "$chosen_base" ]]; then
    chosen_base="$b"
  fi
done

if [[ -z "$chosen_base" ]]; then
  echo "Error: none of staging/main/master exist on origin. Cannot pick base branch." >&2
  exit 1
fi

echo "Base branch resolved: $chosen_base"

# Create the worktree.
if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
  if git show-ref --verify --quiet "refs/heads/$branch_name"; then
    echo "Reusing local branch '$branch_name' for the worktree."
    git worktree add "$worktree_dir" "$branch_name"
  else
    echo "Checking out remote branch '$branch_name' into worktree..."
    git worktree add "$worktree_dir" "$branch_name"
  fi
elif git show-ref --verify --quiet "refs/heads/$branch_name"; then
  echo "Reusing local-only branch '$branch_name' for the worktree."
  git worktree add "$worktree_dir" "$branch_name"
else
  echo "Creating new branch '$branch_name' from '$chosen_base'..."
  git worktree add -b "$branch_name" "$worktree_dir" "$chosen_base"
fi

# Copy env files from the main repo.
for f in .env .envrc; do
  if [[ -f "$git_root/$f" && ! -f "$worktree_dir/$f" ]]; then
    echo "Copying $f to worktree..."
    cp "$git_root/$f" "$worktree_dir/$f"
  fi
done

if [[ -f "$worktree_dir/.envrc" ]] && command -v direnv >/dev/null 2>&1; then
  (cd "$worktree_dir" && direnv allow)
fi

refresh_codex_trust

echo ""
echo "Worktree ready: $worktree_dir"
echo "WORKTREE_PATH=$worktree_dir"
