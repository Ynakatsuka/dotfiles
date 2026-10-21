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
        --dangerously-bypass-hook-trust \
        "${config_args[@]}" \
        "$@"
}
