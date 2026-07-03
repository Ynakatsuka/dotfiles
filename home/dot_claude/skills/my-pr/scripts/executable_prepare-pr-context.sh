#!/usr/bin/env bash
set -euo pipefail

if (($# > 0)); then
  echo "ERROR: unexpected argument: $1" >&2
  exit 1
fi

: "${MY_PR_ARTIFACT_DIR:?Run prepare-review-artifacts.sh first and source MY_PR_ARTIFACT_ENV when resuming}"

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

mkdir -p "$MY_PR_ARTIFACT_DIR"

metadata_json="$MY_PR_ARTIFACT_DIR/pr-metadata.json"
issue_comments_json="$MY_PR_ARTIFACT_DIR/pr-issue-comments.json"
reviews_json="$MY_PR_ARTIFACT_DIR/pr-reviews.json"
review_comments_json="$MY_PR_ARTIFACT_DIR/pr-review-comments.json"
context_md="$MY_PR_ARTIFACT_DIR/pr-context.md"
err_file="$MY_PR_ARTIFACT_DIR/pr-context.err"

pr_fields='number,title,state,isDraft,author,body,baseRefName,headRefName,url,createdAt,updatedAt,closingIssuesReferences,reviewRequests,labels'

if ! gh pr view --json "$pr_fields" >"$metadata_json" 2>"$err_file"; then
  if grep -Eqi 'no pull requests|not found' "$err_file"; then
    cat >"$metadata_json" <<'EOF'
{
  "state": "no_existing_pr"
}
EOF
    cat >"$context_md" <<'EOF'
# PR Context

State: no existing PR for the current branch.

There is no PR body or prior GitHub conversation to review. Do not infer missing PR discussion.
EOF
    printf '[]\n' >"$issue_comments_json"
    printf '[]\n' >"$reviews_json"
    printf '[]\n' >"$review_comments_json"
    context_state="no_existing_pr"
  else
    cat "$err_file" >&2
    exit 1
  fi
else
  jq -e '
    (.number | type == "number") and
    (.title | type == "string") and
    (.state | type == "string") and
    (.baseRefName | type == "string") and
    (.headRefName | type == "string") and
    (.url | type == "string")
  ' "$metadata_json" >/dev/null

  pr_number=$(jq -r '.number' "$metadata_json")
  repo_now=$(gh repo view --json nameWithOwner -q .nameWithOwner)

  fetch_paginated_array() {
    local endpoint=$1
    local output=$2
    local paged_output
    paged_output=$(mktemp "$MY_PR_ARTIFACT_DIR/paged.XXXXXX.json")
    gh api --paginate --slurp "$endpoint" >"$paged_output"
    jq '[.[][]]' "$paged_output" >"$output"
    rm -f "$paged_output"
  }

  fetch_paginated_array "repos/${repo_now}/issues/${pr_number}/comments" "$issue_comments_json"
  fetch_paginated_array "repos/${repo_now}/pulls/${pr_number}/reviews" "$reviews_json"
  fetch_paginated_array "repos/${repo_now}/pulls/${pr_number}/comments" "$review_comments_json"

  {
    jq -r '
      def text_or_marker($value; $marker):
        if ($value == null) or ($value == "") then $marker else ($value | tostring) end;
      "# PR Context",
      "",
      ("PR: #" + (.number | tostring) + " " + .title),
      ("State: " + .state + " / Draft: " + (.isDraft | tostring)),
      ("URL: " + .url),
      ("Author: " + text_or_marker(.author.login; "[missing author login]")),
      ("Base: " + .baseRefName + " / Head: " + .headRefName),
      ("Created: " + text_or_marker(.createdAt; "[missing createdAt]")),
      ("Updated: " + text_or_marker(.updatedAt; "[missing updatedAt]")),
      ("Labels: " + (if (.labels | length) == 0 then "[none]" else ([.labels[] | text_or_marker(.name; "[missing label name]")] | join(", ")) end)),
      ("Closing issues: " + (if (.closingIssuesReferences | length) == 0 then "[none]" else ([.closingIssuesReferences[] | "#" + (.number | tostring) + " " + text_or_marker(.title; "[missing issue title]") + " " + text_or_marker(.url; "[missing issue URL]")] | join("; ")) end)),
      "",
      "## PR body",
      "",
      text_or_marker(.body; "[empty PR body]")
    ' "$metadata_json"

    printf '\n## Top-level comments\n\n'
    jq -r '
      def text_or_marker($value; $marker):
        if ($value == null) or ($value == "") then $marker else ($value | tostring) end;
      def body_text:
        if (.body == null) or (.body == "") then "[empty comment body]" else .body end;
      if length == 0 then
        "- [none]"
      else
        .[] |
        "- " + text_or_marker(.user.login; "[missing author login]") + " at " + text_or_marker(.created_at; "[missing created_at]") + " (" + text_or_marker(.html_url; "[missing URL]") + ")\n" +
        (body_text | split("\n") | map("  " + .) | join("\n"))
      end
    ' "$issue_comments_json"

    printf '\n## Reviews\n\n'
    jq -r '
      def text_or_marker($value; $marker):
        if ($value == null) or ($value == "") then $marker else ($value | tostring) end;
      def body_text:
        if (.body == null) or (.body == "") then "[empty review body]" else .body end;
      if length == 0 then
        "- [none]"
      else
        .[] |
        "- " + text_or_marker(.user.login; "[missing author login]") + " " + text_or_marker(.state; "[missing review state]") + " at " + text_or_marker(.submitted_at; "[missing submitted_at]") + " (" + text_or_marker(.html_url; "[missing URL]") + ")\n" +
        (body_text | split("\n") | map("  " + .) | join("\n"))
      end
    ' "$reviews_json"

    printf '\n## Inline review comments\n\n'
    jq -r '
      def text_or_marker($value; $marker):
        if ($value == null) or ($value == "") then $marker else ($value | tostring) end;
      def body_text:
        if (.body == null) or (.body == "") then "[empty inline comment body]" else .body end;
      if length == 0 then
        "- [none]"
      else
        .[] |
        "- " + text_or_marker(.user.login; "[missing author login]") + " on " + text_or_marker(.path; "[missing path]") + ":" + text_or_marker((.line // .original_line); "[missing line]") + " at " + text_or_marker(.created_at; "[missing created_at]") + " (" + text_or_marker(.html_url; "[missing URL]") + ")\n" +
        (body_text | split("\n") | map("  " + .) | join("\n"))
      end
    ' "$review_comments_json"
  } >"$context_md"

  context_state="found"
fi

artifact_env="${MY_PR_ARTIFACT_ENV:-$MY_PR_ARTIFACT_DIR/artifact.env}"
context_env="$MY_PR_ARTIFACT_DIR/pr-context.env"
{
  printf 'export MY_PR_CONTEXT=%q\n' "$context_md"
  printf 'export MY_PR_CONTEXT_STATE=%q\n' "$context_state"
  printf 'export MY_PR_METADATA=%q\n' "$metadata_json"
  printf 'export MY_PR_ISSUE_COMMENTS=%q\n' "$issue_comments_json"
  printf 'export MY_PR_REVIEWS=%q\n' "$reviews_json"
  printf 'export MY_PR_REVIEW_COMMENTS=%q\n' "$review_comments_json"
} >"$context_env"

cat "$context_env" >>"$artifact_env"
latest_env="$(dirname "$MY_PR_ARTIFACT_DIR")/latest-env.sh"
if [[ -f "$latest_env" ]]; then
  cp "$artifact_env" "$latest_env"
fi

cat "$context_env"
rm -f "$context_env"
printf 'PR context artifact: %s\n' "$context_md" >&2
