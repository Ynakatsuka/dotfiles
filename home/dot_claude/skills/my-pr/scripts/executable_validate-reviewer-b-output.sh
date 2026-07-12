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

markers=(
  '## PR understanding'
  '## Strengths'
  '## Findings'
  '## Non-findings'
  '## Assessment'
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

if ! grep -Fq '**Ready to merge?**' "$review_file"; then
  echo "ERROR: Reviewer B output is missing required assessment: **Ready to merge?**" >&2
  exit 1
fi
if ! grep -Fq '**Reasoning:**' "$review_file"; then
  echo "ERROR: Reviewer B output is missing required assessment: **Reasoning:**" >&2
  exit 1
fi

printf 'Reviewer B output is valid: %s\n' "$review_file"
