#!/usr/bin/env bash
# Disk cleanup script for macOS and Ubuntu
# Usage: cleanup.sh [--dry-run] [--category CATEGORY] [--include-volumes]
# Categories: docker, brew, apt, pip, npm, yarn, tmp, all
# --include-volumes: also prune unused Docker volumes (may delete DB data).
set -euo pipefail

DRY_RUN=false
CATEGORY="all"
INCLUDE_VOLUMES=false
OS_TYPE="$(uname -s)"
CURRENT_CATEGORY=""
FAILURES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --category)
      CATEGORY="$2"
      shift 2
      ;;
    --include-volumes)
      INCLUDE_VOLUMES=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

bytes_to_human() {
  local bytes=$1
  # Use awk for float division so this works without bc installed.
  if ((bytes >= 1073741824)); then
    awk -v b="$bytes" 'BEGIN { printf "%.1f GB", b / 1073741824 }'
  elif ((bytes >= 1048576)); then
    awk -v b="$bytes" 'BEGIN { printf "%.1f MB", b / 1048576 }'
  elif ((bytes >= 1024)); then
    awk -v b="$bytes" 'BEGIN { printf "%.1f KB", b / 1024 }'
  else
    printf "%d B" "$bytes"
  fi
}

get_disk_available() {
  # printf "%d" avoids awk emitting large byte counts in scientific notation,
  # which would break the integer arithmetic in bytes_to_human.
  df -k / | awk 'NR==2 {printf "%d", $4 * 1024}'
}

dir_size_bytes() {
  local path="$1"
  if [[ -d "$path" ]]; then
    local result
    result=$(du -sk "$path" 2>/dev/null | awk 'NR==1{printf "%d", $1 * 1024}')
    echo "${result:-0}"
  else
    echo 0
  fi
}

report_category() {
  local name="$1" size="$2"
  printf "  %-25s %s\n" "$name" "$(bytes_to_human "$size")"
}

# Record a failed step (warn immediately, list again in the final summary).
record_failure() {
  local exit_code="$1" description="$2"
  echo "  [WARN] command failed (exit ${exit_code}): ${description}" >&2
  FAILURES+=("${CURRENT_CATEGORY:-general}: ${description} (exit ${exit_code})")
}

# Run a command from its argument vector (no eval, no stderr suppression).
# On failure, warn and record it, but keep going through remaining steps.
run_or_dry() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
    return 0
  fi
  # Record the failure but return 0 so `set -e` does not abort remaining steps.
  # The recorded failures drive the final exit code.
  local rc=0
  "$@" || rc=$?
  if ((rc != 0)); then
    record_failure "$rc" "$*"
  fi
  return 0
}

# Run a command that genuinely needs a shell (pipelines, globs) via bash -c.
# Same failure handling as run_or_dry. Usage:
#   run_or_dry_shell <description> <shell_code> [bash_arg ...]
# Positional bash args are exposed to <shell_code> as $1, $2, ... (the leading
# _ occupies $0), so paths are passed as data rather than interpolated.
run_or_dry_shell() {
  local description="$1"
  local shell_code="$2"
  shift 2
  if $DRY_RUN; then
    echo "  [dry-run] $description"
    return 0
  fi
  # Record the failure but return 0 so `set -e` does not abort remaining steps.
  local rc=0
  bash -c "$shell_code" _ "$@" || rc=$?
  if ((rc != 0)); then
    record_failure "$rc" "$description"
  fi
  return 0
}

# Delete the contents of a directory, guarded so an empty/unset path can never
# expand into a destructive `rm -rf /*`.
remove_dir_contents() {
  local dir="$1"
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    echo "  [skip] not a directory: ${dir:-<empty>}"
    return 0
  fi
  run_or_dry_shell "rm -rf ${dir}/*" 'rm -rf "$1"/*' "$dir"
}

# ── Docker ──
cleanup_docker() {
  if ! command -v docker &>/dev/null; then
    echo "  docker: not installed, skipping"
    return
  fi
  if ! docker info &>/dev/null; then
    echo "  docker: daemon not running, skipping"
    return
  fi
  local before
  before=$(docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1 || echo "unknown")
  echo "  Docker reclaimable (approx): $before"
  # Volumes often hold data (DBs, etc.); only prune them with explicit opt-in.
  if $INCLUDE_VOLUMES; then
    run_or_dry docker system prune -af --volumes
  else
    run_or_dry docker system prune -af
    echo "  (volumes kept; pass --include-volumes to prune them)"
  fi
  run_or_dry docker builder prune -af
  echo "  Docker cleanup done"
}

# ── Homebrew (macOS) ──
cleanup_brew() {
  if ! command -v brew &>/dev/null; then
    echo "  brew: not installed, skipping"
    return
  fi
  local cache_dir rc=0
  cache_dir="$(brew --cache)" || rc=$?
  # Guard: an empty cache_dir would otherwise turn the removal below into a
  # destructive path expansion. Record the failure instead of proceeding.
  if [[ -z "$cache_dir" ]]; then
    record_failure "$rc" "brew --cache returned no cache directory; skipping Homebrew cleanup"
    return
  fi
  local size
  size=$(dir_size_bytes "$cache_dir")
  report_category "Homebrew cache" "$size"
  run_or_dry brew cleanup --prune=all -s
  remove_dir_contents "$cache_dir"
  echo "  Homebrew cleanup done"
}

# ── APT (Ubuntu) ──
cleanup_apt() {
  if ! command -v apt-get &>/dev/null; then
    echo "  apt: not available, skipping"
    return
  fi
  local size
  size=$(dir_size_bytes "/var/cache/apt/archives")
  report_category "APT cache" "$size"
  run_or_dry sudo apt-get clean -y
  run_or_dry sudo apt-get autoremove -y
  echo "  APT cleanup done"
}

# ── pip ──
cleanup_pip() {
  if ! command -v pip &>/dev/null && ! command -v pip3 &>/dev/null; then
    echo "  pip: not installed, skipping"
    return
  fi
  local pip_cmd="pip3"
  command -v pip3 &>/dev/null || pip_cmd="pip"
  local cache_dir
  cache_dir=$($pip_cmd cache dir 2>/dev/null || echo "")
  if [[ -n "$cache_dir" ]]; then
    local size
    size=$(dir_size_bytes "$cache_dir")
    report_category "pip cache" "$size"
    run_or_dry "$pip_cmd" cache purge
  else
    echo "  pip cache: not found"
  fi
  echo "  pip cleanup done"
}

# ── npm ──
cleanup_npm() {
  if ! command -v npm &>/dev/null; then
    echo "  npm: not installed, skipping"
    return
  fi
  local cache_dir
  cache_dir=$(npm config get cache 2>/dev/null || echo "$HOME/.npm")
  local size
  size=$(dir_size_bytes "$cache_dir")
  report_category "npm cache" "$size"
  run_or_dry npm cache clean --force
  echo "  npm cleanup done"
}

# ── yarn ──
cleanup_yarn() {
  if ! command -v yarn &>/dev/null; then
    echo "  yarn: not installed, skipping"
    return
  fi
  local cache_dir
  cache_dir=$(yarn cache dir 2>/dev/null || echo "")
  if [[ -n "$cache_dir" ]]; then
    local size
    size=$(dir_size_bytes "$cache_dir")
    report_category "yarn cache" "$size"
    run_or_dry yarn cache clean
  fi
  echo "  yarn cleanup done"
}

# ── Tmp files ──
cleanup_tmp() {
  local total=0
  # macOS caches
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    local user_cache="$HOME/Library/Caches"
    local size
    size=$(dir_size_bytes "$user_cache")
    # shellcheck disable=SC2088 # display label, not a path
    report_category '~/Library/Caches' "$size"
    total=$((total + size))

    local xcode_dd="$HOME/Library/Developer/Xcode/DerivedData"
    size=$(dir_size_bytes "$xcode_dd")
    if ((size > 0)); then
      report_category "Xcode DerivedData" "$size"
      total=$((total + size))
      remove_dir_contents "$xcode_dd"
    fi

    # System logs
    local sys_logs="/private/var/log"
    size=$(dir_size_bytes "$sys_logs")
    report_category "System logs" "$size"
  fi

  # Common tmp directories
  local tmp_size
  tmp_size=$(dir_size_bytes "/tmp")
  report_category "/tmp" "$tmp_size"

  # Python caches in home
  local pycache_size=0
  while IFS= read -r -d '' d; do
    local s
    s=$(dir_size_bytes "$d")
    pycache_size=$((pycache_size + s))
  done < <(find "$HOME" -maxdepth 4 -name "__pycache__" -type d -print0 2>/dev/null)
  if ((pycache_size > 0)); then
    report_category "__pycache__ (depth 4)" "$pycache_size"
    if $DRY_RUN; then
      echo "  [dry-run] find \"\$HOME\" -maxdepth 4 -name __pycache__ -type d -exec rm -rf {} +"
    elif ! find "$HOME" -maxdepth 4 -name "__pycache__" -type d -exec rm -rf {} +; then
      echo "  [WARN] command failed: remove __pycache__ directories" >&2
      FAILED_STEPS=$((FAILED_STEPS + 1))
    fi
  fi

  # .mypy_cache
  local mypy_size=0
  while IFS= read -r -d '' d; do
    local s
    s=$(dir_size_bytes "$d")
    mypy_size=$((mypy_size + s))
  done < <(find "$HOME" -maxdepth 4 -name ".mypy_cache" -type d -print0 2>/dev/null)
  if ((mypy_size > 0)); then
    report_category ".mypy_cache (depth 4)" "$mypy_size"
    if $DRY_RUN; then
      echo "  [dry-run] find \"\$HOME\" -maxdepth 4 -name .mypy_cache -type d -exec rm -rf {} +"
    elif ! find "$HOME" -maxdepth 4 -name ".mypy_cache" -type d -exec rm -rf {} +; then
      echo "  [WARN] command failed: remove .mypy_cache directories" >&2
      FAILED_STEPS=$((FAILED_STEPS + 1))
    fi
  fi

  echo "  Tmp cleanup done"
}

# ── Main ──
echo "========================================="
echo "  Disk Cleanup - $(date '+%Y-%m-%d %H:%M')"
echo "  OS: $OS_TYPE"
$DRY_RUN && echo "  Mode: DRY RUN (no files deleted)"
echo "========================================="

BEFORE=$(get_disk_available)
echo ""
echo "Disk available before: $(bytes_to_human "$BEFORE")"
echo ""

categories=()
if [[ "$CATEGORY" == "all" ]]; then
  categories=(docker brew apt pip npm yarn tmp)
else
  IFS=',' read -ra categories <<<"$CATEGORY"
fi

for cat in "${categories[@]}"; do
  echo "── $cat ──"
  case "$cat" in
    docker) cleanup_docker ;;
    brew) cleanup_brew ;;
    apt) cleanup_apt ;;
    pip) cleanup_pip ;;
    npm) cleanup_npm ;;
    yarn) cleanup_yarn ;;
    tmp) cleanup_tmp ;;
    *) echo "  Unknown category: $cat" ;;
  esac
  echo ""
done

AFTER=$(get_disk_available)
FREED=$((AFTER - BEFORE))
echo "========================================="
echo "  Disk available after:  $(bytes_to_human "$AFTER")"
if ((FREED > 0)); then
  echo "  Space freed:           $(bytes_to_human "$FREED")"
else
  echo "  Space freed:           (negligible or N/A)"
fi
echo "========================================="

if ((FAILED_STEPS > 0)); then
  echo "  $FAILED_STEPS cleanup step(s) failed. See [WARN] lines above." >&2
  exit 1
fi
