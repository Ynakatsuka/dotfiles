#!/usr/bin/env bash
# Exercise age backup and restoration with real encryption and a local 1Password stub.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/test-age-key.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT

for tool in age age-keygen jq python3 rg; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "test-age-key: required command not found: $tool" >&2
    exit 1
  }
done

fail() {
  echo "test-age-key: $*" >&2
  sed -n '1,35p' "$test_dir/output" >&2
  exit 1
}

mkdir -p "$test_dir/repo/bootstrap" "$test_dir/repo/home/private_dot_ssh" "$test_dir/bin" "$test_dir/store"
cp "$repo_root/bootstrap/age-key.sh" "$test_dir/repo/bootstrap/age-key.sh"
age-keygen --output "$test_dir/original.key" 2>/dev/null
recipient=$(age-keygen -y "$test_dir/original.key")
printf 'fixture plaintext\n' |
  age --encrypt --recipient "$recipient" --output "$test_dir/repo/home/private_dot_ssh/encrypted_private_config.age"
age-keygen --output "$test_dir/wrong.key" 2>/dev/null

cat >"$test_dir/bin/op" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
fixture_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
store="$fixture_root/store"
[[ "$1" == document ]] || exit 8
operation=$2
shift 2
input=''
output=''
case "$operation" in
  create | get)
    input=$1
    shift
    ;;
esac
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-file)
      output=$2
      shift 2
      ;;
    --vault | --format | --title | --file-name | --file-mode)
      shift 2
      ;;
    *) exit 8 ;;
  esac
done
case "$operation" in
  list)
    if [[ -f "$store/duplicate" ]]; then
      printf '[{"id":"document-1","title":"chezmoi age key"},{"id":"document-2","title":"chezmoi age key"}]\n'
    elif [[ -f "$store/key.txt" ]]; then
      printf '[{"id":"document-1","title":"chezmoi age key"}]\n'
    else
      printf '[]\n'
    fi
    ;;
  create)
    printf 'create\n' >>"$store/calls"
    cp "$input" "$store/key.txt"
    # Creation receipts need not use the document-list field names.
    printf '{"uuid":"document-1"}\n'
    ;;
  get)
    [[ -n "$output" && "$input" == document-1 ]] || exit 8
    if [[ -f "$store/download-fails" ]]; then
      printf 'partial download\n' >"$output"
      echo 'simulated download failure' >&2
      exit 9
    fi
    cp "$store/key.txt" "$output"
    # Restoration must enforce 0600 even if a downloader returns a wider mode.
    chmod 644 "$output"
    if [[ -f "$store/race-target" ]]; then
      IFS= read -r race_target <"$store/race-target"
      if [[ -f "$store/race-directory" ]]; then
        mkdir "$race_target"
      elif [[ -f "$store/race-symlink" ]]; then
        mkdir -p "$store/race-link-destination"
        ln -s "$store/race-link-destination" "$race_target"
      else
        printf 'concurrent file\n' >"$race_target"
      fi
    fi
    ;;
  *) exit 8 ;;
esac
STUB
chmod +x "$test_dir/bin/op"

run() {
  env PATH="$test_dir/bin:$PATH" bash "$test_dir/repo/bootstrap/age-key.sh" "$@" >"$test_dir/output" 2>&1
}

if run backup "$test_dir/wrong.key"; then fail 'backup accepted a key that cannot decrypt this repository'; fi
[[ ! -e "$test_dir/store/key.txt" ]] || fail 'invalid key was uploaded'

run backup "$test_dir/original.key" || fail 'initial backup failed'
cmp -s "$test_dir/original.key" "$test_dir/store/key.txt" || fail 'backup differs from the original'
run backup "$test_dir/original.key" || fail 'matching backup was not reusable'
[[ $(wc -l <"$test_dir/store/calls") -eq 1 ]] || fail 'repeated backup created a duplicate'

cp "$test_dir/original.key" "$test_dir/changed.key"
printf '# different local file\n' >>"$test_dir/changed.key"
if run backup "$test_dir/changed.key"; then fail 'backup replaced a different existing document'; fi
cmp -s "$test_dir/original.key" "$test_dir/store/key.txt" || fail 'existing document was overwritten'

restored="$test_dir/restored/key.txt"
run restore "$restored" || fail 'restore failed'
cmp -s "$test_dir/original.key" "$restored" || fail 'restored key differs from the original'
python3 - "$restored" <<'PY'
import os
import stat
import sys

assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600
PY
age --decrypt --identity "$restored" "$test_dir/repo/home/private_dot_ssh/encrypted_private_config.age" >/dev/null
if run restore "$restored"; then fail 'restore overwrote an existing key'; fi
cmp -s "$test_dir/original.key" "$restored" || fail 'existing identity was changed'

ln -s "$test_dir/missing-target" "$test_dir/key-link"
if run restore "$test_dir/key-link"; then fail 'restore accepted an existing symlink'; fi
[[ -L "$test_dir/key-link" && ! -e "$test_dir/missing-target" ]] || fail 'restore changed a symlink target'

cp "$test_dir/wrong.key" "$test_dir/store/key.txt"
if run restore "$test_dir/rejected/key.txt"; then fail 'restore accepted the wrong document key'; fi
[[ ! -e "$test_dir/rejected/key.txt" ]] || fail 'invalid restored key was installed'
cp "$test_dir/original.key" "$test_dir/store/key.txt"

touch "$test_dir/store/download-fails"
if run restore "$test_dir/partial/key.txt"; then fail 'restore ignored a failed download'; fi
[[ ! -e "$test_dir/partial/key.txt" ]] || fail 'partial download was installed'
rm "$test_dir/store/download-fails"

touch "$test_dir/store/duplicate"
if run restore "$test_dir/duplicate/key.txt"; then fail 'restore accepted ambiguous document names'; fi
[[ ! -e "$test_dir/duplicate/key.txt" ]] || fail 'ambiguous document was installed'
rm "$test_dir/store/duplicate"

printf '%s\n' "$test_dir/race/key.txt" >"$test_dir/store/race-target"
if run restore "$test_dir/race/key.txt"; then fail 'restore overwrote a file created during download'; fi
[[ $(<"$test_dir/race/key.txt") == 'concurrent file' ]] || fail 'concurrent file was overwritten'
touch "$test_dir/store/race-directory"
printf '%s\n' "$test_dir/race/directory" >"$test_dir/store/race-target"
if run restore "$test_dir/race/directory"; then fail 'restore accepted a directory created during download'; fi
[[ -d "$test_dir/race/directory" && ! -e "$test_dir/race/directory/key.txt" ]] || fail 'restore placed a key inside a concurrent directory'
rm "$test_dir/store/race-directory"

touch "$test_dir/store/race-symlink"
printf '%s\n' "$test_dir/race/symlink" >"$test_dir/store/race-target"
if run restore "$test_dir/race/symlink"; then fail 'restore accepted a symlink created during download'; fi
[[ -L "$test_dir/race/symlink" && ! -e "$test_dir/store/race-link-destination/key.txt" ]] || fail 'restore placed a key through a concurrent symlink'
rm "$test_dir/store/race-symlink"
rm "$test_dir/store/race-target"

if find "$test_dir" -type d -name '.age-key-restore.*' -print | rg -q .; then
  fail 'restore left a temporary key directory behind'
fi
if rg -q 'AGE-SECRET-KEY-' "$test_dir/output"; then fail 'error output exposed an identity'; fi

echo 'test-age-key: OK'
