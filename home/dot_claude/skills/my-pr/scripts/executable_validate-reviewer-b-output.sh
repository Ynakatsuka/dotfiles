#!/usr/bin/env bash
set -euo pipefail

review_file=${1:?Usage: validate-reviewer-b-output.sh <review-markdown>}
if (($# > 1)); then
  echo "ERROR: unexpected argument: $2" >&2
  exit 1
fi
if [[ ! -s "$review_file" ]]; then
  echo "ERROR: Reviewer B output not found or empty: $review_file" >&2
  exit 1
fi

forbidden_markers=(
  '## Strengths'
  '## Non-findings'
)
for forbidden in "${forbidden_markers[@]}"; do
  if grep -n -m 1 -Fx -- "$forbidden" "$review_file" >/dev/null; then
    echo "ERROR: Reviewer B output must not include a removed section: $forbidden" >&2
    exit 1
  fi
done

markers=(
  '## PR understanding'
  '## Findings'
)
previous_line=0
for marker in "${markers[@]}"; do
  marker_line=$(grep -n -m 1 -Fx -- "$marker" "$review_file" | cut -d: -f1 || true)
  if [[ -z "$marker_line" ]]; then
    echo "ERROR: Reviewer B output is missing required section: $marker" >&2
    exit 1
  fi
  if ((marker_line <= previous_line)); then
    echo "ERROR: Reviewer B output sections are out of order: $marker" >&2
    exit 1
  fi
  previous_line=$marker_line
done

# The terminal line proves the saved body was not cut off mid-finding.
last_line=$(awk 'NF { line = $0 } END { print line }' "$review_file")
if [[ "$last_line" != '<!-- END OF REVIEW -->' ]]; then
  echo "ERROR: Reviewer B output does not end with the required terminal line: <!-- END OF REVIEW -->" >&2
  exit 1
fi

printf 'Reviewer B output is valid: %s\n' "$review_file"
