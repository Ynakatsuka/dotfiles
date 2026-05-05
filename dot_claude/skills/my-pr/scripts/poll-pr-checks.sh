#!/usr/bin/env bash
set -euo pipefail

pr_number=${1:?Usage: poll-pr-checks.sh <pr-number> [max-iterations] [sleep-seconds]}
max_iterations=${2:-10}
sleep_seconds=${3:-60}

checks_clear=0
checks_need_fix=0
checks_json=""

for i in $(seq 1 "$max_iterations"); do
  echo "Waiting for GitHub checks: iteration $i/$max_iterations"
  sleep "$sleep_seconds"

  err_file=$(mktemp)
  if checks_json=$(gh pr checks "$pr_number" --json name,bucket,state,workflow,link 2>"$err_file"); then
    rm -f "$err_file"
  else
    status=$?
    if rg -qi "no checks|checks have not been created|not found" "$err_file"; then
      rm -f "$err_file"
      echo "No checks are configured for this PR."
      checks_clear=1
      break
    fi
    cat "$err_file" >&2
    rm -f "$err_file"
    exit "$status"
  fi

  printf '%s\n' "$checks_json"

  if [[ -n "$checks_json" ]] && printf '%s\n' "$checks_json" | jq -e 'any(.[]; .bucket == "fail" or .bucket == "cancel")' >/dev/null; then
    checks_need_fix=1
    break
  fi

  if [[ -n "$checks_json" ]] && printf '%s\n' "$checks_json" | jq -e 'any(.[]; .bucket == "pending")' >/dev/null; then
    continue
  fi

  if [[ -n "$checks_json" ]]; then
    checks_clear=1
    break
  fi
done

if [[ "$checks_need_fix" -eq 1 ]]; then
  echo "Checks failed or were cancelled. Inspect logs and fix root cause." >&2
  exit 2
fi

if [[ "$checks_clear" -ne 1 ]]; then
  echo "Checks did not finish within the wait limit." >&2
  if [[ -n "$checks_json" ]]; then
    printf '%s\n' "$checks_json" | jq -r '.[] | select(.bucket == "pending") | "\(.name) \(.link)"' >&2
  fi
  exit 3
fi

echo "Checks are clear."
