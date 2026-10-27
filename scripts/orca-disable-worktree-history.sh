#!/usr/bin/env bash
# Orca の worktree 別シェル履歴 (terminalScopeHistoryByWorktree) を無効にし、
# 全ターミナルで ~/.zsh_history を共有させる。設定画面に項目がないため DB を直接書き換える。
#
# Orca は起動中の設定をメモリに持ち保存時に DB を上書きするので、終了中に書き換える必要がある。
#   bash scripts/orca-disable-worktree-history.sh            # Orca 終了済みで実行
#   bash scripts/orca-disable-worktree-history.sh --restart  # Orca を終了→変更→再起動
set -euo pipefail

restart=false
case "${1:-}" in
  "") ;;
  --restart) restart=true ;;
  *)
    echo "usage: $0 [--restart]" >&2
    exit 2
    ;;
esac

orca_dir="$HOME/Library/Application Support/orca"
profile_id=$(jq -er '.activeProfileId' "$orca_dir/orca-profile-index.json")
db="$orca_dir/profiles/$profile_id/profile-state.db"
[[ -f "$db" ]] || {
  echo "Orca の設定 DB が見つかりません: $db" >&2
  exit 1
}

if $restart && pgrep -x Orca >/dev/null; then
  osascript -e 'quit app "Orca"'
  for _ in $(seq 60); do
    pgrep -x Orca >/dev/null || break
    sleep 1
  done
fi
if pgrep -x Orca >/dev/null; then
  echo "Orca が起動中です。Orca を終了してから再実行してください。" >&2
  exit 1
fi

backup="$db.bak-$(date +%Y%m%d%H%M%S)"
sqlite3 "$db" ".backup '$backup'"
echo "backup: $backup"

payload=$(sqlite3 "$db" "select payload from profile_state_documents where domain='settings'")
new_payload=$(jq -c '.terminalScopeHistoryByWorktree = false' <<<"$payload")
# content_hash は payload の SHA-256。
hash=$(printf '%s' "$new_payload" | shasum -a 256 | cut -d' ' -f1)
now_ms=$(($(date +%s) * 1000))
escaped=${new_payload//\'/\'\'}
sqlite3 "$db" "update profile_state_documents set payload='$escaped', content_hash='$hash', updated_at=$now_ms where domain='settings'"

sqlite3 "$db" "select payload from profile_state_documents where domain='settings'" |
  jq -e '.terminalScopeHistoryByWorktree == false' >/dev/null
echo "terminalScopeHistoryByWorktree=false に変更しました。"

if $restart; then
  open -a Orca
fi
