#!/usr/bin/env bash

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
prune_script="$repo_root/home/dot_local/bin/executable_prune-old-worktrees"
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/prune-old-worktrees-test.XXXXXX")
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

ghq_root="$tmp_dir/ghq"
main_repo="$ghq_root/github.com/example/app"
worktree_base="${main_repo}-worktree"
api_root="$tmp_dir/ccv"
conversation_dir="$tmp_dir/conversation-logs"
now_epoch=2000000000
old_epoch=$((now_epoch - 40 * 24 * 60 * 60))
recent_epoch=$((now_epoch - 5 * 24 * 60 * 60))

mkdir -p "$main_repo" "$worktree_base" "$api_root/api/projects" "$conversation_dir"
git -C "$main_repo" init -q -b main
git -C "$main_repo" config user.email test@example.com
git -C "$main_repo" config user.name Test
printf 'base\n' >"$main_repo/README.md"
git -C "$main_repo" add README.md
git -C "$main_repo" commit -qm initial

for name in old old-no-session old-unmerged old-upstream old-base-fallback old-race recent-file recent-session; do
  git -C "$main_repo" worktree add -qb "$name" "$worktree_base/$name"
done
git -C "$main_repo" worktree add -qb release/old "$worktree_base/old-protected"
git -C "$main_repo" worktree add -q --detach "$worktree_base/old-detached" main

printf 'unmerged\n' >"$worktree_base/old-unmerged/unmerged.txt"
git -C "$worktree_base/old-unmerged" add unmerged.txt
git -C "$worktree_base/old-unmerged" commit -qm unmerged
printf 'upstream\n' >"$worktree_base/old-upstream/upstream.txt"
git -C "$worktree_base/old-upstream" add upstream.txt
git -C "$worktree_base/old-upstream" commit -qm upstream
printf 'base fallback\n' >"$worktree_base/old-base-fallback/base-fallback.txt"
git -C "$worktree_base/old-base-fallback" add base-fallback.txt
git -C "$worktree_base/old-base-fallback" commit -qm base-fallback
upstream_unmerged_oid=$(printf 'upstream unmerged\n' | \
  git -C "$main_repo" commit-tree refs/heads/main^{tree} -p refs/heads/main)
git -C "$main_repo" update-ref refs/heads/upstream-unmerged "$upstream_unmerged_oid"
git -C "$main_repo" update-ref \
  refs/remotes/origin/staging refs/heads/old-base-fallback
git -C "$main_repo" update-ref refs/remotes/origin/main refs/heads/old-unmerged
git -C "$main_repo" branch upstream-target old-upstream
git -C "$main_repo" config branch.old-upstream.remote .
git -C "$main_repo" config branch.old-upstream.merge refs/heads/upstream-target
git -C "$main_repo" config branch.old-base-fallback.remote .
git -C "$main_repo" config \
  branch.old-base-fallback.merge refs/heads/upstream-unmerged

touch -d "@$old_epoch" \
  "$worktree_base/old/README.md" \
  "$worktree_base/old-no-session/README.md"
touch -d "@$old_epoch" \
  "$worktree_base/old-unmerged/README.md" \
  "$worktree_base/old-unmerged/unmerged.txt" \
  "$worktree_base/old-upstream/README.md" \
  "$worktree_base/old-upstream/upstream.txt" \
  "$worktree_base/old-base-fallback/README.md" \
  "$worktree_base/old-base-fallback/base-fallback.txt" \
  "$worktree_base/old-race/README.md" \
  "$worktree_base/old-protected/README.md" \
  "$worktree_base/old-detached/README.md"
touch -d "@$recent_epoch" "$worktree_base/recent-file/README.md"
touch -d "@$old_epoch" "$worktree_base/recent-session/README.md"

mkdir -p "$api_root/api/worktree-cleanup/config"
write_cleanup_config() {
  local enabled=$1
  local delete_branch_mode=${2:-merged}
  cat >"$api_root/api/worktree-cleanup/config/index.html" <<JSON
{"config":{"enabled":$enabled,"retentionDays":30,"deleteBranchMode":"$delete_branch_mode"}}
JSON
}
write_cleanup_config false

cat >"$api_root/api/projects/index.html" <<JSON
{"projects":[
  {"id":"old","meta":{"isWorktree":true,"projectPath":"$worktree_base/old","mainRepoPath":"$main_repo"}},
  {"id":"old-no-session","meta":{"isWorktree":true,"projectPath":"$worktree_base/old-no-session","mainRepoPath":"$main_repo"}},
  {"id":"old-unmerged","meta":{"isWorktree":true,"projectPath":"$worktree_base/old-unmerged","mainRepoPath":"$main_repo"}},
  {"id":"old-upstream","meta":{"isWorktree":true,"projectPath":"$worktree_base/old-upstream","mainRepoPath":"$main_repo"}},
  {"id":"old-base-fallback","meta":{"isWorktree":true,"projectPath":"$worktree_base/old-base-fallback","mainRepoPath":"$main_repo"}},
  {"id":"old-race","meta":{"isWorktree":true,"projectPath":"$worktree_base/old-race","mainRepoPath":"$main_repo"}},
  {"id":"old-protected","meta":{"isWorktree":true,"projectPath":"$worktree_base/old-protected","mainRepoPath":"$main_repo"}},
  {"id":"old-detached","meta":{"isWorktree":true,"projectPath":"$worktree_base/old-detached","mainRepoPath":"$main_repo"}},
  {"id":"recent-file","meta":{"isWorktree":true,"projectPath":"$worktree_base/recent-file","mainRepoPath":"$main_repo"}},
  {"id":"recent-session","meta":{"isWorktree":true,"projectPath":"$worktree_base/recent-session","mainRepoPath":"$main_repo"}}
]}
JSON

for name in old old-no-session old-unmerged old-upstream old-base-fallback old-race old-protected old-detached recent-file recent-session; do
  mkdir -p "$api_root/api/projects/$name/latest-session"
  session_epoch=$old_epoch
  if [[ "$name" == "recent-session" ]]; then
    session_epoch=$recent_epoch
  fi
  session_timestamp=$(date -u -d "@$session_epoch" +%Y-%m-%dT%H:%M:%SZ)
  conversation_path="$conversation_dir/$name.jsonl"
  printf '{"cwd":"%s"}\n' "$worktree_base/$name" >"$conversation_path"
  cat >"$api_root/api/projects/$name/latest-session/index.html" <<JSON
{"latestSession":{"lastModifiedAt":"$session_timestamp","jsonlFilePath":"$conversation_path"}}
JSON
done
cat >"$api_root/api/projects/old-no-session/latest-session/index.html" <<JSON
{"latestSession":null}
JSON
rm "$conversation_dir/old-no-session.jsonl"

port_file="$tmp_dir/server-port"
race_count_file="$tmp_dir/old-race-request-count"
old_session_timestamp=$(date -u -d "@$old_epoch" +%Y-%m-%dT%H:%M:%SZ)
recent_session_timestamp=$(date -u -d "@$recent_epoch" +%Y-%m-%dT%H:%M:%SZ)
printf '0' >"$race_count_file"
python3 - \
  "$api_root" \
  "$port_file" \
  "$race_count_file" \
  "$old_session_timestamp" \
  "$recent_session_timestamp" \
  "$conversation_dir/old-race.jsonl" <<'PY' &
import http.server
import json
import pathlib
import sys


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        if self.path.rstrip("/") == "/api/projects/old-race/latest-session":
            count_path = pathlib.Path(sys.argv[3])
            count = int(count_path.read_text(encoding="utf-8")) + 1
            count_path.write_text(str(count), encoding="utf-8")
            body = json.dumps(
                {
                    "latestSession": {
                        "lastModifiedAt": sys.argv[5] if count >= 2 else sys.argv[4],
                        "jsonlFilePath": sys.argv[6],
                    }
                }
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()


root = sys.argv[1]
port_file = pathlib.Path(sys.argv[2])
handler = lambda *args, **kwargs: QuietHandler(*args, directory=root, **kwargs)
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
port_file.write_text(str(server.server_port), encoding="utf-8")
server.serve_forever()
PY
server_pid=$!

for _ in {1..50}; do
  [[ -s "$port_file" ]] && break
  sleep 0.1
done
[[ -s "$port_file" ]]
ccv_origin="http://127.0.0.1:$(<"$port_file")"

disabled_output=$(
  python3 "$prune_script" \
    --apply \
    --ghq-root "$ghq_root" \
    --ccv-origin "$ccv_origin" \
    --now-epoch "$now_epoch"
)
grep -Fq 'DISABLED worktree cleanup is disabled in CCV' <<<"$disabled_output"
[[ -d "$worktree_base/old" ]]
[[ -d "$worktree_base/old-unmerged" ]]

write_cleanup_config true
dry_run_output=$(
  python3 "$prune_script" \
    --ghq-root "$ghq_root" \
    --ccv-origin "$ccv_origin" \
    --now-epoch "$now_epoch"
)

grep -Fq "CANDIDATE $worktree_base/old" <<<"$dry_run_output"
grep -Fq "CANDIDATE $worktree_base/old-no-session" <<<"$dry_run_output"
grep -Fq "session=none" <<<"$dry_run_output"
grep -Fq "CANDIDATE $worktree_base/old-unmerged" <<<"$dry_run_output"
grep -Fq "CANDIDATE $worktree_base/old-upstream" <<<"$dry_run_output"
grep -Fq "CANDIDATE $worktree_base/old-base-fallback" <<<"$dry_run_output"
grep -Fq "CANDIDATE $worktree_base/old-race" <<<"$dry_run_output"
grep -Fq "CANDIDATE $worktree_base/old-protected" <<<"$dry_run_output"
grep -Fq "CANDIDATE $worktree_base/old-detached" <<<"$dry_run_output"
grep -Fq "KEEP $worktree_base/recent-file" <<<"$dry_run_output"
grep -Fq "KEEP $worktree_base/recent-session" <<<"$dry_run_output"
grep -Fq 'DRY-RUN candidates=8 inspected=10' <<<"$dry_run_output"

printf '0' >"$race_count_file"
apply_output=$(python3 "$prune_script" \
  --apply \
  --ghq-root "$ghq_root" \
  --ccv-origin "$ccv_origin" \
  --now-epoch "$now_epoch")
grep -Fq "KEEP-UPDATED $worktree_base/old-race" <<<"$apply_output"

[[ ! -e "$worktree_base/old" ]]
[[ ! -e "$worktree_base/old-no-session" ]]
[[ ! -e "$worktree_base/old-unmerged" ]]
[[ ! -e "$worktree_base/old-upstream" ]]
[[ ! -e "$worktree_base/old-base-fallback" ]]
[[ -d "$worktree_base/old-race" ]]
[[ ! -e "$worktree_base/old-protected" ]]
[[ ! -e "$worktree_base/old-detached" ]]
[[ -d "$worktree_base/recent-file" ]]
[[ -d "$worktree_base/recent-session" ]]
if git -C "$main_repo" show-ref --verify --quiet refs/heads/old; then
  echo 'merged old branch was not deleted' >&2
  exit 1
fi
if git -C "$main_repo" show-ref --verify --quiet refs/heads/old-no-session; then
  echo 'merged branch without a session was not deleted' >&2
  exit 1
fi
[[ ! -e "$conversation_dir/old-no-session.jsonl" ]]
git -C "$main_repo" show-ref --verify --quiet refs/heads/old-unmerged
git -C "$main_repo" show-ref --verify --quiet refs/heads/old-race
if git -C "$main_repo" show-ref --verify --quiet refs/heads/old-upstream; then
  echo 'branch merged into its upstream was not deleted' >&2
  exit 1
fi
if git -C "$main_repo" show-ref --verify --quiet refs/heads/old-base-fallback; then
  echo 'branch merged into base but not upstream was not deleted' >&2
  exit 1
fi
git -C "$main_repo" show-ref --verify --quiet refs/heads/release/old
[[ -f "$conversation_dir/old.jsonl" ]]
[[ -f "$conversation_dir/old-unmerged.jsonl" ]]
[[ -f "$conversation_dir/old-race.jsonl" ]]
[[ -f "$conversation_dir/recent-file.jsonl" ]]
[[ -f "$conversation_dir/recent-session.jsonl" ]]

git -C "$main_repo" worktree add -qb old-keep "$worktree_base/old-keep"
touch -d "@$old_epoch" "$worktree_base/old-keep/README.md"
mkdir -p "$api_root/api/projects/old-keep/latest-session"
session_timestamp=$(date -u -d "@$old_epoch" +%Y-%m-%dT%H:%M:%SZ)
conversation_path="$conversation_dir/old-keep.jsonl"
printf '{"cwd":"%s"}\n' "$worktree_base/old-keep" >"$conversation_path"
cat >"$api_root/api/projects/old-keep/latest-session/index.html" <<JSON
{"latestSession":{"lastModifiedAt":"$session_timestamp","jsonlFilePath":"$conversation_path"}}
JSON
cat >"$api_root/api/projects/index.html" <<JSON
{"projects":[
  {"id":"old-keep","meta":{"isWorktree":true,"projectPath":"$worktree_base/old-keep","mainRepoPath":"$main_repo"}}
]}
JSON
write_cleanup_config true keep

python3 "$prune_script" \
  --apply \
  --ghq-root "$ghq_root" \
  --ccv-origin "$ccv_origin" \
  --now-epoch "$now_epoch" >/dev/null

[[ ! -e "$worktree_base/old-keep" ]]
git -C "$main_repo" show-ref --verify --quiet refs/heads/old-keep
[[ -f "$conversation_path" ]]

printf 'test-prune-old-worktrees: OK\n'
