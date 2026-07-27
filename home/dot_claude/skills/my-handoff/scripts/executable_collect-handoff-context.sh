#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

if ! repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  fail "run this command inside a Git working tree"
fi
cd "$repo_root"

if ! branch=$(git symbolic-ref --quiet --short HEAD); then
  fail "detached HEAD cannot identify a branch for handoff"
fi

working_tree=$(git status --porcelain=v1 --untracked-files=all)
if [[ -n "$working_tree" ]]; then
  echo "ERROR: working tree contains local-only changes" >&2
  printf '%s\n' "$working_tree" >&2
  exit 1
fi

if ! upstream_ref=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
  fail "branch '$branch' has no upstream"
fi

if ! remote_name=$(git config --get "branch.${branch}.remote"); then
  fail "branch '$branch' has no configured remote"
fi
if ! merge_ref=$(git config --get "branch.${branch}.merge"); then
  fail "branch '$branch' has no configured remote branch"
fi
if [[ "$merge_ref" != refs/heads/* ]]; then
  fail "unsupported upstream ref: $merge_ref"
fi
remote_branch=${merge_ref#refs/heads/}

if [[ "$upstream_ref" != "$remote_name/$remote_branch" ]]; then
  fail "upstream '$upstream_ref' does not match configured branch '$remote_name/$remote_branch'"
fi

if ! remote_url=$(git remote get-url "$remote_name"); then
  fail "could not resolve URL for remote '$remote_name'"
fi

case "$remote_url" in
  https://*)
    [[ "$remote_url" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?/[A-Za-z0-9._~/-]+$ ]] ||
      fail "remote URL contains unsupported or sensitive components"
    ;;
  git@*:*)
    [[ "$remote_url" =~ ^git@[A-Za-z0-9.-]+:[A-Za-z0-9._~/-]+$ ]] ||
      fail "remote URL contains unsupported or sensitive components"
    ;;
  ssh://git@*)
    [[ "$remote_url" =~ ^ssh://git@[A-Za-z0-9.-]+(:[0-9]+)?/[A-Za-z0-9._~/-]+$ ]] ||
      fail "remote URL contains unsupported or sensitive components"
    ;;
  git://*)
    [[ "$remote_url" =~ ^git://[A-Za-z0-9.-]+(:[0-9]+)?/[A-Za-z0-9._~/-]+$ ]] ||
      fail "remote URL contains unsupported or sensitive components"
    ;;
  *) fail "remote URL is not an approved cross-machine URL" ;;
esac

if git grep -Eq 'filter[[:space:]]*=[[:space:]]*lfs' HEAD -- \
  .gitattributes ':(glob)**/.gitattributes'; then
  fail "Git LFS is configured; remote LFS object availability is not verified by this skill"
else
  lfs_search_status=$?
  if ((lfs_search_status > 1)); then
    fail "could not inspect Git attributes for LFS usage"
  fi
fi

submodule_entries=$(git ls-tree -r HEAD | sed -n 's/^160000 commit [0-9a-f]*\t//p')
if [[ -n "$submodule_entries" ]]; then
  echo "ERROR: submodules are present; remote submodule commits are not verified by this skill" >&2
  printf '%s\n' "$submodule_entries" >&2
  exit 1
fi

head_sha=$(git rev-parse HEAD)
if ! remote_output=$(git ls-remote --exit-code "$remote_name" "$merge_ref"); then
  fail "could not read remote branch '$remote_name/$remote_branch'"
fi

remote_sha=""
while IFS=$'\t' read -r candidate_sha candidate_ref; do
  if [[ "$candidate_ref" == "$merge_ref" ]]; then
    remote_sha=$candidate_sha
    break
  fi
done <<<"$remote_output"

if [[ -z "$remote_sha" ]]; then
  fail "remote branch '$remote_name/$remote_branch' does not exist"
fi
if [[ "$head_sha" != "$remote_sha" ]]; then
  echo "ERROR: local HEAD and remote branch are not identical" >&2
  printf 'local_head=%s\nremote_head=%s\n' "$head_sha" "$remote_sha" >&2
  exit 1
fi

share_kind="branch"
pr_url=""
base_branch=""
pr_lookup="not_applicable"
github_repo=""

case "$remote_url" in
  git@github.com:*) github_repo=${remote_url#git@github.com:} ;;
  http://github.com/*) github_repo=${remote_url#http://github.com/} ;;
  https://github.com/*) github_repo=${remote_url#https://github.com/} ;;
  ssh://git@github.com/*) github_repo=${remote_url#ssh://git@github.com/} ;;
  git://github.com/*) github_repo=${remote_url#git://github.com/} ;;
esac
github_repo=${github_repo%.git}

if [[ -n "$github_repo" ]]; then
  case "$github_repo" in
    /* | */ | */*/*) fail "could not parse GitHub repository from remote URL: $remote_url" ;;
    */*) ;;
    *) fail "could not parse GitHub repository from remote URL: $remote_url" ;;
  esac

  if command -v gh >/dev/null 2>&1; then
    pr_lookup="checked"
    if ! pr_output=$(gh pr list \
      --repo "$github_repo" \
      --head "$remote_branch" \
      --state open \
      --limit 100 \
      --json url,headRefOid,headRefName,headRepository,baseRefName \
      --template '{{range .}}{{.url}}{{"\t"}}{{.headRefOid}}{{"\t"}}{{.headRefName}}{{"\t"}}{{.headRepository.nameWithOwner}}{{"\t"}}{{.baseRefName}}{{"\n"}}{{end}}' 2>&1); then
      echo "ERROR: GitHub PR lookup failed" >&2
      printf '%s\n' "$pr_output" >&2
      exit 1
    fi

    pr_count=0
    pr_head_sha=""
    while IFS=$'\t' read -r candidate_url candidate_head_sha candidate_head_branch candidate_repo candidate_base_branch; do
      [[ -z "$candidate_url" ]] && continue
      if [[ "${candidate_repo,,}" != "${github_repo,,}" ]]; then
        continue
      fi
      if [[ "$candidate_head_branch" != "$remote_branch" ]]; then
        fail "PR head branch '$candidate_head_branch' does not match remote branch '$remote_branch'"
      fi
      pr_count=$((pr_count + 1))
      pr_url=$candidate_url
      pr_head_sha=$candidate_head_sha
      base_branch=$candidate_base_branch
    done <<<"$pr_output"

    if ((pr_count > 1)); then
      fail "multiple open PRs use branch '$branch'; choose one explicitly"
    fi
    if ((pr_count == 1)); then
      if [[ "$pr_head_sha" != "$head_sha" ]]; then
        fail "open PR head '$pr_head_sha' does not match local HEAD '$head_sha'"
      fi
      share_kind="pr"
    fi
  else
    pr_lookup="unavailable"
  fi
fi

printf 'share_kind=%q\n' "$share_kind"
printf 'pr_lookup=%q\n' "$pr_lookup"
printf 'remote_name=%q\n' "$remote_name"
printf 'remote_url=%q\n' "$remote_url"
printf 'branch=%q\n' "$remote_branch"
printf 'commit=%q\n' "$head_sha"
if [[ "$share_kind" == "pr" ]]; then
  printf 'pr_url=%q\n' "$pr_url"
  printf 'base_branch=%q\n' "$base_branch"
fi
