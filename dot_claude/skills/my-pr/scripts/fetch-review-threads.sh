#!/usr/bin/env bash
set -euo pipefail

pr_number=${1:?Usage: fetch-review-threads.sh <pr-number>}
owner=$(gh repo view --json owner -q .owner.login)
repo=$(gh repo view --json name -q .name)

echo "# PR view"
gh pr view "$pr_number" --json reviews,comments,latestReviews,reviewDecision

echo "# Review comments"
gh api "repos/{owner}/{repo}/pulls/$pr_number/comments"

echo "# Review threads"
after=""
while :; do
  if [[ -z "$after" ]]; then
    page=$(gh api graphql \
      -f owner="$owner" \
      -f repo="$repo" \
      -F number="$pr_number" \
      -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved
          comments(first: 20) { nodes { author { login } body path line url } }
        }
      }
    }
  }
}')
  else
    page=$(gh api graphql \
      -f owner="$owner" \
      -f repo="$repo" \
      -F number="$pr_number" \
      -f after="$after" \
      -f query='
query($owner: String!, $repo: String!, $number: Int!, $after: String!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved
          comments(first: 20) { nodes { author { login } body path line url } }
        }
      }
    }
  }
}')
  fi

  printf '%s\n' "$page"

  has_next=$(printf '%s\n' "$page" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  after=$(printf '%s\n' "$page" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor // empty')

  if [[ "$has_next" != "true" ]]; then
    break
  fi

  if [[ -z "$after" ]]; then
    echo "ERROR: GitHub reported another page but did not return an endCursor" >&2
    exit 1
  fi
done
