#!/usr/bin/env bash
set -euo pipefail

# Runs Reviewer A and Reviewer C concurrently for one chunk. Prompt-level
# instructions cannot guarantee that the orchestrator issues both calls in the
# same turn, so this wrapper owns the concurrency instead.

usage='Usage: run-codex-reviews.sh <chunk-id> <chunk-count> <reviewer-a-prompt> <reviewer-c-prompt> <context-file> <diff-file>'
if (($# != 6)); then
  echo "ERROR: $usage" >&2
  exit 1
fi

chunk_id=$1
chunk_count=$2
prompt_a=$3
prompt_c=$4
context_file=$5
diff_file=$6

# Validate before any path is built from chunk_id, since launch_dir below is
# passed straight to rm -rf. Reject "." and ".." explicitly: the character
# class alone would otherwise accept them and let chunk_id walk out of the
# artifact tree.
if [[ ! "$chunk_id" =~ ^[A-Za-z0-9._-]+$ ]] || [[ "$chunk_id" == "." ]] || [[ "$chunk_id" == ".." ]]; then
  echo "ERROR: invalid chunk id: $chunk_id" >&2
  exit 1
fi
if [[ ! "$chunk_count" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: chunk count must be a positive integer: $chunk_count" >&2
  exit 1
fi
if [[ ! -s "$context_file" ]]; then
  echo "ERROR: context file not found or empty: $context_file" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
runner="$script_dir/run-codex-review.sh"
if [[ ! -f "$runner" ]]; then
  echo "ERROR: reviewer runner not found: $runner" >&2
  exit 1
fi

artifact_dir=$(cd "$(dirname "$context_file")" && pwd -P)
launch_dir="$artifact_dir/reviewer-results/parallel/$chunk_id"
rm -rf "$launch_dir"
mkdir -p "$launch_dir"

# The runner prints its review Markdown path on stdout. Capture each stream
# separately so a failure in one reviewer cannot be mistaken for the other's.
bash "$runner" reviewer-a "$chunk_id" "$chunk_count" "$prompt_a" "$context_file" "$diff_file" \
  >"$launch_dir/reviewer-a.path" 2>"$launch_dir/reviewer-a.err" &
pid_a=$!
bash "$runner" reviewer-c "$chunk_id" "$chunk_count" "$prompt_c" "$context_file" "$diff_file" \
  >"$launch_dir/reviewer-c.path" 2>"$launch_dir/reviewer-c.err" &
pid_c=$!

status_a=0
wait "$pid_a" || status_a=$?
status_c=0
wait "$pid_c" || status_c=$?

report_failure() {
  local reviewer=$1
  local status=$2
  echo "ERROR: Reviewer $reviewer failed: chunk=$chunk_id exit=$status" >&2
  cat "$launch_dir/reviewer-${reviewer}.err" >&2
}

if ((status_a != 0)); then
  report_failure a "$status_a"
fi
if ((status_c != 0)); then
  report_failure c "$status_c"
fi
if ((status_a != 0 || status_c != 0)); then
  echo "ERROR: review is incomplete for chunk $chunk_id; do not integrate partial results" >&2
  exit 1
fi

review_a=$(cat "$launch_dir/reviewer-a.path")
review_c=$(cat "$launch_dir/reviewer-c.path")
for review_file in "$review_a" "$review_c"; do
  if [[ ! -s "$review_file" ]]; then
    echo "ERROR: reviewer output is missing or empty: $review_file" >&2
    exit 1
  fi
done

printf 'reviewer-a\t%s\n' "$review_a"
printf 'reviewer-c\t%s\n' "$review_c"
