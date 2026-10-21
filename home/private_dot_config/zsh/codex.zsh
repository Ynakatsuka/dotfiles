#
# Codex Integration
#

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
    local -a trust_paths
    local -A seen_paths

    logical_project_path=$(cd "$project_dir" && pwd -L) || return 1
    physical_project_path=$(cd "$project_dir" && pwd -P) || return 1
    trust_paths=("$logical_project_path" "$physical_project_path")

    if git_root=$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null); then
        physical_git_root=$(cd "$git_root" && pwd -P) || return 1
        trust_paths+=("$git_root" "$physical_git_root")
    fi

    # Trust the project for this run only instead of appending to config.toml.
    # Codex ignores a dotted `projects."<path>".trust_level` override, while an
    # inline table merges with config.toml. A later `projects=` override would
    # replace this one, so every path goes into the same table.
    local trust_path escaped_project_path trusted_projects=""
    for trust_path in "${trust_paths[@]}"; do
        if [[ -n "${seen_paths[$trust_path]}" ]]; then
            continue
        fi
        seen_paths[$trust_path]=1
        escaped_project_path=${trust_path//\\/\\\\}
        escaped_project_path=${escaped_project_path//\"/\\\"}
        trusted_projects+="${trusted_projects:+,}\"$escaped_project_path\"={trust_level=\"trusted\"}"
    done

    codex \
        --dangerously-bypass-approvals-and-sandbox \
        --dangerously-bypass-hook-trust \
        -c "projects={$trusted_projects}" \
        "$@"
}
