#
# Codex Integration
#

_codex_trust_project_path() {
    local trust_path="$1"
    local codex_home="${CODEX_HOME:-$HOME/.codex}"
    local config_file="$codex_home/config.toml"
    local escaped_project_path

    mkdir -p "$codex_home" || return 1
    touch "$config_file" || return 1

    escaped_project_path=${trust_path//\\/\\\\}
    escaped_project_path=${escaped_project_path//\"/\\\"}

    if grep -F -x -q -- "[projects.\"$escaped_project_path\"]" "$config_file"; then
        return 0
    fi

    {
        printf '\n[projects."%s"]\n' "$escaped_project_path"
        printf 'trust_level = "trusted"\n'
    } >> "$config_file"
}

# Codex launcher (mirrors `cl` for claude)
function cdx() {
    local project_dir="$PWD"
    local i=1

    while ((i <= $#)); do
        case "${argv[$i]}" in
            -C | --cd)
                ((i++))
                if ((i > $#)); then
                    echo "Error: ${argv[$((i - 1))]} requires a directory" >&2
                    return 2
                fi
                project_dir="${argv[$i]}"
                ;;
            -C=*)
                project_dir="${argv[$i]#-C=}"
                ;;
            --cd=*)
                project_dir="${argv[$i]#--cd=}"
                ;;
        esac
        ((i++))
    done

    if [ ! -d "$project_dir" ]; then
        echo "Error: Codex project directory not found: $project_dir" >&2
        return 1
    fi

    local logical_project_path physical_project_path git_root physical_git_root
    local -a trust_paths config_args
    local -A seen_paths

    logical_project_path=$(cd "$project_dir" && pwd -L) || return 1
    physical_project_path=$(cd "$project_dir" && pwd -P) || return 1
    trust_paths=("$logical_project_path" "$physical_project_path")

    if git_root=$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null); then
        physical_git_root=$(cd "$git_root" && pwd -P) || return 1
        trust_paths+=("$git_root" "$physical_git_root")
    fi

    local trust_path escaped_project_path
    for trust_path in "${trust_paths[@]}"; do
        if [[ -n "${seen_paths[$trust_path]}" ]]; then
            continue
        fi
        seen_paths[$trust_path]=1
        escaped_project_path=${trust_path//\\/\\\\}
        escaped_project_path=${escaped_project_path//\"/\\\"}
        _codex_trust_project_path "$trust_path" || return 1
        config_args+=(-c "projects.\"$escaped_project_path\".trust_level=\"trusted\"")
    done

    codex \
        --dangerously-bypass-approvals-and-sandbox \
        "${config_args[@]}" \
        "$@"
}

# Internal helper: portable dev:inode fetch
_codex_devino() {
  if stat -c '%d:%i' "$1" >/dev/null 2>&1; then
    stat -c '%d:%i' "$1"
  else
    stat -f '%d:%i' "$1"
  fi
}

# Core sync helper
_codex_sync_impl() {
  local src="$1" dest="$2"
  if [ ! -d "$src" ]; then
    echo "Source directory not found: $src" >&2
    return 1
  fi
  mkdir -p "$dest"
  local src_real dest_real
  src_real=$(readlink -f "$src" 2>/dev/null || printf %s "$src")
  dest_real=$(readlink -f "$dest" 2>/dev/null || printf %s "$dest")
  if [ -d "$dest_real" ] && [ "$(_codex_devino "$src_real")" = "$(_codex_devino "$dest_real")" ]; then
    echo "Source and destination refer to the same directory; nothing to do."
    return 0
  fi
  if command -v rsync >/dev/null 2>&1; then
    rsync -av --delete "$src_real"/ "$dest_real"/
  else
    find "$dest_real" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    cp -a "$src_real"/. "$dest_real"/
  fi
  echo "Synced: $src_real -> $dest_real"
}

# Flattening sync helper: subdir/file.md -> subdir-file.md
_codex_flatten_sync_impl() {
  local src="$1" dest="$2"
  if [ ! -d "$src" ]; then
    echo "Source directory not found: $src" >&2
    return 1
  fi
  mkdir -p "$dest"
  local src_real dest_real
  src_real=$(readlink -f "$src" 2>/dev/null || printf %s "$src")
  dest_real=$(readlink -f "$dest" 2>/dev/null || printf %s "$dest")

  if [ -d "$dest_real" ] && [ "$(_codex_devino "$src_real")" = "$(_codex_devino "$dest_real")" ]; then
    echo "Source and destination refer to the same directory; aborting to avoid self-sync." >&2
    echo "  src:  $src_real" >&2
    echo "  dest: $dest_real" >&2
    echo "Hint: 引数で別の出力先を指定するか、シンボリックリンクを外してください。" >&2
    return 1
  fi

  find "$dest_real" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

  while IFS= read -r -d '' file; do
    local rel flattened target base ext n src_base
    rel=${file#"$src_real/"}
    flattened=${rel//\//-}

    src_base=$(basename "$src_real")
    if [[ "$src_base" != "commands" && "$flattened" != ${src_base}-* ]]; then
      flattened="${src_base}-${flattened}"
    fi

    target="$dest_real/$flattened"

    if [ -e "$target" ]; then
      if [[ "$flattened" == *.* ]]; then
        base="${flattened%.*}"; ext=".${flattened##*.}"
      else
        base="$flattened"; ext=""
      fi
      n=2
      while [ -e "$dest_real/${base}-${n}${ext}" ]; do n=$((n+1)); done
      target="$dest_real/${base}-${n}${ext}"
    fi

    cp -a "$file" "$target"
  done < <(find "$src_real" -type f -print0)

  echo "Flatten-synced: $src_real -> $dest_real"
}

# Default repo sync
codex-sync() {
  local guessed_src
  if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    guessed_src="$git_root/.claude/commands"
  fi
  local fallback_src="/home/claude-code/Documents/src/github.com/Revie0701/insightx/.claude/commands"
  local src="${1:-${guessed_src:-$fallback_src}}"
  local dest="${2:-$HOME/.codex/prompts}"
  _codex_flatten_sync_impl "$src" "$dest"
}
