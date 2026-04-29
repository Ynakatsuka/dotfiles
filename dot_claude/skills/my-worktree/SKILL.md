---
name: my-worktree
description: >-
  Create a git worktree using the project's `{repo}-worktree/{branch}` convention,
  always pulling origin/staging, origin/main, and origin/master first so the new
  branch is based on up-to-date refs. Use when the user asks to create a new
  worktree or start work on a new branch in a worktree (e.g. "ワークツリー作って",
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
3. For each of `staging`, `main`, `master` that exists on origin, fast-forwards the local copy — pulls inside whichever worktree has it checked out, otherwise `git fetch origin <b>:<b>`. Fails loudly on divergence.
4. Picks the highest-priority existing base branch (staging > main > master) for new branches.
5. Creates the worktree at `${repo_root}-worktree/${branch//\//-}`.
6. Copies `.env` / `.envrc` from the main repo and runs `direnv allow` when present.

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

- Local `staging` / `main` / `master` has diverged from origin → script exits 1. Relay the message; ask the user how to reconcile (rebase / reset / etc).
- Uncommitted changes in a worktree that holds a base branch → `pull --ff-only` fails. Relay the path; do not auto-stash.
- None of staging/main/master exist on origin → exit 1. Ask the user which base branch to use; this skill does not handle that case.
- Branch directory already exists but is unregistered → exit 1. Inspect manually; do not delete.

## Boundary with related tools

- `gw` (zsh function in `private_dot_config/zsh/git-worktree.zsh`) — interactive sibling; only fast-forwards staging *or* main, not all three. Prefer this skill when the user explicitly wants the "always pull all base branches" guarantee.
- **my-pr** — creates its own worktree before committing on a protected branch.
- **my-sdd** — Phase 3-0 creates a worktree as part of the spec-driven gate.
- For removing worktrees, use `gwc`; for listing, `git worktree list`.
