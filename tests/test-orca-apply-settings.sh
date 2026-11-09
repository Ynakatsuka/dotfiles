#!/usr/bin/env bash
# Regression tests for orca-apply-settings. Orca validates each document's
# content_hash and writes against the store revision, so a write must keep both
# consistent, preserve unowned fields, and never run while Orca is open.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_orca-apply-settings"
export ORCA_USER_DATA_PATH="$TMP_DIR/orca"
DB="$ORCA_USER_DATA_PATH/profiles/p1/profile-state.db"
mkdir -p "$(dirname "$DB")" "$TMP_DIR/path"
printf '{"activeProfileId":"p1"}' >"$ORCA_USER_DATA_PATH/orca-profile-index.json"

# Fake ps: lists the Orca main process while this file exists.
RUNNING_FLAG="$TMP_DIR/orca-running"
cat >"$TMP_DIR/path/ps" <<EOF
#!/usr/bin/env bash
echo /usr/bin/login
[[ ! -e "$RUNNING_FLAG" ]] || echo /Applications/Orca.app/Contents/MacOS/Orca
EOF
chmod +x "$TMP_DIR/path/ps"
export PATH="$TMP_DIR/path:$PATH"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

settings='{"defaultTuiAgent":"codex","refreshLocalBaseRefOnWorktreeCreate":false,"terminalScopeHistoryByWorktree":true,"keep":"it'"'"'s","terminalQuickCommands":[{"id":"user","label":"Mine","action":"terminal-command","command":"ls","appendEnter":true},{"id":"old","label":"Old","action":"terminal-command","command":"orca-workspace-done","appendEnter":false}]}'
ui='{"sortBy":"smart","other":1}'
sqlite3 "$DB" <<SQL
CREATE TABLE profile_state_meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
CREATE TABLE profile_state_documents (
  domain TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL,
  domain_version INTEGER NOT NULL, revision INTEGER NOT NULL,
  updated_at INTEGER NOT NULL, content_hash TEXT NOT NULL);
INSERT INTO profile_state_meta VALUES ('profile_id', 'p1'), ('revision', '7');
INSERT INTO profile_state_documents VALUES
  ('settings', '${settings//\'/\'\'}', 1, 5, 0, 'x'),
  ('ui', '$ui', 1, 6, 0, 'y'),
  ('repos', '[]', 1, 2, 0, 'z');
SQL

query() { sqlite3 "$DB" "$1"; }

# Running Orca with pending changes: exit 3 and leave the database untouched.
touch "$RUNNING_FLAG"
status=0
bash "$SCRIPT" >/dev/null 2>&1 || status=$?
[[ $status -eq 3 ]] || fail "expected exit 3 while Orca runs, got $status"
[[ $(query "SELECT value FROM profile_state_meta WHERE key='revision'") == 7 ]] || fail "revision changed while Orca runs"
rm "$RUNNING_FLAG"

bash "$SCRIPT" >/dev/null || fail "apply failed"

[[ $(query "SELECT value FROM profile_state_meta WHERE key='revision'") == 8 ]] || fail "store revision was not bumped once"
[[ $(query "SELECT group_concat(d, ',') FROM (SELECT domain || ':' || revision AS d FROM profile_state_documents ORDER BY domain)") == "repos:2,settings:8,ui:8" ]] ||
  fail "document revisions are wrong"
for domain in settings ui; do
  payload=$(query "SELECT payload FROM profile_state_documents WHERE domain='$domain'")
  hash=$(printf '%s' "$payload" | shasum -a 256 | cut -d' ' -f1)
  [[ $(query "SELECT content_hash FROM profile_state_documents WHERE domain='$domain'") == "$hash" ]] ||
    fail "$domain content_hash does not match its payload"
done

query "SELECT payload FROM profile_state_documents WHERE domain='settings'" | jq -e '
  .defaultTuiAgent == "claude"
  and .refreshLocalBaseRefOnWorktreeCreate == true
  and .terminalScopeHistoryByWorktree == false
  and .keep == "it'"'"'s"
  and ([.terminalQuickCommands[].id] == ["user", "old"])
  and .terminalQuickCommands[1].label == "Mark workspace Done"
  and .terminalQuickCommands[1].appendEnter == true' >/dev/null || fail "settings payload is wrong"
query "SELECT payload FROM profile_state_documents WHERE domain='ui'" |
  jq -e '.sortBy == "manual" and .other == 1' >/dev/null || fail "ui payload is wrong"

# Up to date: no write, even while Orca runs.
touch "$RUNNING_FLAG"
bash "$SCRIPT" >/dev/null || fail "up-to-date run failed while Orca runs"
[[ $(query "SELECT value FROM profile_state_meta WHERE key='revision'") == 8 ]] || fail "up-to-date run wrote"

echo "test-orca-apply-settings: ok"
