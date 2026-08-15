#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SCRIPT="$REPO_ROOT/home/dot_local/libexec/cmux/executable_resume-all-codex-sessions"

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/cmux-resume-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

mock_cmux="$test_dir/cmux"
calls_file="$test_dir/calls"

write_mock_cmux() {
  local fail_surface="${1:-}"

  sed \
    -e "s|@CALLS_FILE@|$calls_file|g" \
    -e "s|@FAIL_SURFACE@|$fail_surface|g" \
    >"$mock_cmux" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == "--json tree --all" ]]; then
  cat <<'JSON'
{
  "windows": [
    {
      "ref": "window:1",
      "workspaces": [
        {
          "ref": "workspace:1",
          "panes": [
            {
              "surfaces": [
                {"ref": "surface:1", "type": "terminal"},
                {"ref": "surface:2", "type": "browser"},
                {"ref": "surface:3", "type": "terminal"}
              ]
            }
          ]
        }
      ]
    },
    {
      "ref": "window:2",
      "workspaces": [
        {
          "ref": "workspace:2",
          "panes": [
            {
              "surfaces": [
                {"ref": "surface:4", "type": "terminal"}
              ]
            }
          ]
        }
      ]
    }
  ]
}
JSON
  exit 0
fi

if [[ "${1:-}" == "--json" && "${2:-}" == "surface" &&
  "${3:-}" == "resume" && "${4:-}" == "show" ]]; then
  surface_ref=""
  while (($# > 0)); do
    if [[ "$1" == "--surface" ]]; then
      surface_ref="${2:-}"
      break
    fi
    shift
  done
  if [[ "$surface_ref" == "@FAIL_SURFACE@" ]]; then
    exit 1
  fi
  case "$surface_ref" in
    surface:1) printf '{"resume_binding":{"kind":"codex","command":"codex resume session-1"}}\n' ;;
    surface:3) printf '{"resume_binding":{"kind":"claude"}}\n' ;;
    surface:4) printf '{"resume_binding":{"kind":"codex","command":"codex resume session-4 --yolo"}}\n' ;;
  esac
  exit 0
fi

if [[ "$1" == "respawn-pane" ]]; then
  printf '%s\n' "$*" >>"@CALLS_FILE@"
  exit 0
fi

printf 'unexpected cmux arguments: %s\n' "$*" >&2
exit 1
MOCK
  chmod +x "$mock_cmux"
}

write_mock_cmux
output=$(CMUX_BIN="$mock_cmux" "$SCRIPT")
[[ "$output" == "Resumed 2 Codex session(s)." ]]
[[ "$(wc -l <"$calls_file" | tr -d ' ')" == "2" ]]
grep -Fq 'respawn-pane --window window:1 --workspace workspace:1 --surface surface:1 --command codex resume session-1' "$calls_file"
grep -Fq 'respawn-pane --window window:2 --workspace workspace:2 --surface surface:4 --command codex resume session-4 --yolo' "$calls_file"
if grep -Fq 'surface:3' "$calls_file"; then
  printf 'non-Codex surface was respawned\n' >&2
  exit 1
fi

: >"$calls_file"
write_mock_cmux 'surface:3'
if CMUX_BIN="$mock_cmux" "$SCRIPT" >/dev/null 2>&1; then
  printf 'resume inspection failure unexpectedly succeeded\n' >&2
  exit 1
fi
[[ ! -s "$calls_file" ]]

printf 'cmux resume-all Codex session tests passed\n'
