---
name: my-worktree
description: >-
  Create a git worktree using the project's `{repo}-worktree/{branch}` convention,
  fetching origin first and basing new branches on the highest-priority remote
  ref (`origin/staging`, then `origin/main`, then `origin/master`). Use when the
  user asks to create a new worktree or start work on a new branch in a worktree (e.g. "ワークツリー作って",
  "worktree 作成", "新しい作業ブランチ", "新規ブランチで作業").
  Do NOT use for removing/listing worktrees (use `gwc` / `git worktree list`),
  for the PR flow (use my-pr — it creates its own worktree on protected branches),
  or for SDD-driven feature work (use my-sdd — Phase 3-0 has its own worktree gate).
argument-hint: "<branch-name>"
allowed-tools: Bash, Read
---

# my-worktree

## What it does

Runs `~/.claude/skills/my-worktree/scripts/create-worktree.sh <branch>`. The script:

1. Resolves to the main (non-worktree) repo root.
2. `git fetch origin --prune`.
3. Fast-forwards local `staging`, `main`, and `master` from origin when their worktrees are clean.
4. Leaves dirty base-branch worktrees unchanged with an explicit warning, while still using fetched `origin/<base>` for the new worktree.
5. Picks the highest-priority remote base ref (`origin/staging` > `origin/main` > `origin/master`) for new branches.
6. Creates new branches directly from that remote ref without an upstream.
7. Creates the worktree at `${repo_root}-worktree/${branch//\//-}`.
8. Copies `.env` / `.envrc` from the main repo and runs `direnv allow` when present.

If a worktree for that branch already exists, prints the existing path and exits 0.

## How to use

1. Confirm the branch name with the user if not supplied. Do not invent one.
2. Run from inside the repo:
   ```bash
   ~/.claude/skills/my-worktree/scripts/create-worktree.sh <branch-name>
   ```
3. The last stdout line is `WORKTREE_PATH=<absolute-path>`. Tell the user to `cd` there — Claude cannot change the user's shell cwd.

## Failure modes

Surface failures, do not paper over them (per `no_implicit_fallbacks`):

- Uncommitted changes in a worktree that holds a base branch are not modified. New branches are based on `origin/<base>` after fetch.
- Local `staging` / `main` / `master` divergence from origin → script exits 1. Relay the message; ask the user how to reconcile (rebase / reset / etc).
- None of staging/main/master exist on origin → exit 1. Ask the user which base branch to use; this skill does not handle that case.
- Branch directory already exists but is unregistered → exit 1. Inspect manually; do not delete.

## Boundary with related tools

- `gw` (zsh function in `private_dot_config/zsh/git-worktree.zsh`) — interactive sibling that delegates creation to the same helper.
- **my-pr** — creates its own worktree before committing on a protected branch.
- **my-sdd** — Phase 3-0 creates a worktree as part of the spec-driven gate.
- For removing worktrees, use `gwc`; for listing, `git worktree list`.
