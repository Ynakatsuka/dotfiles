#!/usr/bin/env bash
set -euo pipefail

usage='Usage: publish-pr-briefing.sh <html-file> <display-name> <file-name> [--replace]'
if (($# < 3 || $# > 4)); then
  echo "ERROR: $usage" >&2
  exit 1
fi

html_file=$1
display_name=$2
file_name=$3
replace=false
if (($# == 4)); then
  if [[ "$4" != "--replace" ]]; then
    echo "ERROR: unexpected argument: $4" >&2
    echo "ERROR: $usage" >&2
    exit 1
  fi
  replace=true
fi

if [[ ! -f "$html_file" ]]; then
  echo "ERROR: HTML file not found: $html_file" >&2
  exit 1
fi
if [[ "$file_name" != *.html ]]; then
  echo "ERROR: file name must end with .html: $file_name" >&2
  exit 1
fi

base_url="http://localhost:${CCV_PORT:-3434}"
repo_root=$(git rev-parse --show-toplevel)

projects_json=$(curl -sf --max-time 10 "$base_url/api/projects") || {
  echo "ERROR: CCV server is not reachable at $base_url" >&2
  exit 1
}

project_id=$(jq -r --arg route "$repo_root" \
  '[.projects[] | select(.meta.projectPath == $route)] | if length == 1 then .[0].id else empty end' \
  <<<"$projects_json")
if [[ -z "$project_id" ]]; then
  echo "ERROR: no unique CCV project for $repo_root" >&2
  jq -r '.projects[] | "  " + .id + "\t" + (.meta.projectPath // "[no path]")' <<<"$projects_json" >&2
  exit 1
fi

artifacts_url="$base_url/api/projects/$project_id/artifacts"
existing_id=$(curl -sf --max-time 10 "$artifacts_url" |
  jq -r --arg name "$file_name" '[.artifacts[] | select(.fileName == $name)] | (.[0].id // empty)')

request_json=$(mktemp "${TMPDIR:-/tmp}/my-pr-briefing-request.XXXXXX.json")
response_json=$(mktemp "${TMPDIR:-/tmp}/my-pr-briefing-response.XXXXXX.json")
trap 'rm -f "$request_json" "$response_json"' EXIT

jq -n --arg name "$display_name" --arg fileName "$file_name" --rawfile html "$html_file" \
  '{name: $name, fileName: $fileName, html: $html}' >"$request_json"

if [[ -n "$existing_id" ]]; then
  if [[ "$replace" != true ]]; then
    echo "ERROR: artifact already exists with fileName $file_name (id: $existing_id)" >&2
    echo "ERROR: pass --replace to update it" >&2
    exit 1
  fi
  curl -sf --max-time 20 -X PUT "$artifacts_url/$existing_id" \
    -H 'Content-Type: application/json' -d @"$request_json" >"$response_json"
  artifact_id=$existing_id
  action=updated
else
  curl -sf --max-time 20 -X POST "$artifacts_url" \
    -H 'Content-Type: application/json' -d @"$request_json" >"$response_json"
  artifact_id=$(jq -r '.id // empty' "$response_json")
  action=created
fi

if [[ -z "$artifact_id" ]]; then
  echo "ERROR: CCV response did not contain an artifact id" >&2
  cat "$response_json" >&2
  exit 1
fi

printf 'artifact %s\n' "$action"
printf 'artifact id: %s\n' "$artifact_id"
printf 'html url: %s/api/projects/%s/artifacts/%s/html\n' "$base_url" "$project_id" "$artifact_id"
