#!/usr/bin/env bash
# Disk cleanup script for macOS and Ubuntu
# Usage: cleanup.sh [--dry-run] [--category CATEGORY]
# Categories: docker, brew, apt, pip, npm, yarn, tmp, all
set -euo pipefail

DRY_RUN=false
CATEGORY="all"
OS_TYPE="$(uname -s)"

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
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

bytes_to_human() {
  local bytes=$1
  if ((bytes >= 1073741824)); then
    printf "%.1f GB" "$(echo "scale=1; $bytes / 1073741824" | bc)"
  elif ((bytes >= 1048576)); then
    printf "%.1f MB" "$(echo "scale=1; $bytes / 1048576" | bc)"
  elif ((bytes >= 1024)); then
    printf "%.1f KB" "$(echo "scale=1; $bytes / 1024" | bc)"
  else
    printf "%d B" "$bytes"
  fi
}

get_disk_available() {
  if [[ "$OS_TYPE" == "Darwin" ]]; then
    df -k / | awk 'NR==2 {print $4 * 1024}'
  else
    df -k / | awk 'NR==2 {print $4 * 1024}'
  fi
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

run_or_dry() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    eval "$*" 2>/dev/null || true
  fi
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
  run_or_dry "docker system prune -af --volumes"
  run_or_dry "docker builder prune -af"
  echo "  Docker cleanup done"
}

# ── Homebrew (macOS) ──
cleanup_brew() {
  if ! command -v brew &>/dev/null; then
    echo "  brew: not installed, skipping"
    return
  fi
  local cache_dir
  cache_dir="$(brew --cache 2>/dev/null)"
  local size
  size=$(dir_size_bytes "$cache_dir")
  report_category "Homebrew cache" "$size"
  run_or_dry "brew cleanup --prune=all -s"
  run_or_dry "rm -rf '$cache_dir'/*"
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
  run_or_dry "sudo apt-get clean -y"
  run_or_dry "sudo apt-get autoremove -y"
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
    run_or_dry "$pip_cmd cache purge"
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
  run_or_dry "npm cache clean --force"
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
    run_or_dry "yarn cache clean"
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
      run_or_dry "rm -rf '$xcode_dd'/*"
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
    if ! $DRY_RUN; then
      find "$HOME" -maxdepth 4 -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
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
    if ! $DRY_RUN; then
      find "$HOME" -maxdepth 4 -name ".mypy_cache" -type d -exec rm -rf {} + 2>/dev/null || true
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
