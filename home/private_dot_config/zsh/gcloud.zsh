#
# Automatic gcloud configuration switching based on directory path
#
# Rules are loaded from ~/.config/gcloud/config-map (one per line):
#   <path-pattern>:<config-name>
#
# Pattern is a substring match against $PWD, checked in definition order.
# Lines starting with # and blank lines are ignored.
#

typeset -ga _gcloud_config_rules=()

# Reauthenticate the gcloud CLI and refresh the per-configuration ADC file.
gcloud-reauth() {
    local config_name="${1:-${CLOUDSDK_ACTIVE_CONFIG_NAME:-}}"
    if [[ -z "$config_name" ]]; then
        print -u2 "Usage: gcloud-reauth <configuration>"
        return 2
    fi

    local account project
    account=$(gcloud config configurations describe "$config_name" --format="value(properties.core.account)") || return
    project=$(gcloud config configurations describe "$config_name" --format="value(properties.core.project)") || return
    if [[ -z "$account" || -z "$project" ]]; then
        print -u2 "gcloud configuration '$config_name' must define core/account and core/project"
        return 1
    fi

    local -a browser_args=()
    if [[ -n "${SSH_CONNECTION:-}" || (-z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" && "$(uname)" != "Darwin") ]]; then
        browser_args=(--no-launch-browser)
    fi

    gcloud auth login "$account" \
        --configuration="$config_name" \
        --project="$project" \
        --force \
        --update-adc \
        "${browser_args[@]}" || return

    local gcloud_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gcloud"
    local adc_source="$gcloud_dir/application_default_credentials.json"
    local adc_file="$gcloud_dir/adc_${config_name}.json"
    if [[ ! -f "$adc_source" ]]; then
        print -u2 "ADC file was not created: $adc_source"
        return 1
    fi
    install -m 600 "$adc_source" "$adc_file" || return

    export CLOUDSDK_ACTIVE_CONFIG_NAME="$config_name"
    export GOOGLE_APPLICATION_CREDENTIALS="$adc_file"
    print "Reauthenticated gcloud configuration '$config_name' and refreshed '$adc_file'."
}

() {
    local mapfile="${XDG_CONFIG_HOME:-$HOME/.config}/gcloud/config-map"
    [[ -r "$mapfile" ]] || return
    local line
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        _gcloud_config_rules+=("$line")
    done < "$mapfile"
}

(( ${#_gcloud_config_rules} )) || return

_auto_gcloud_config() {
    local rule config_name adc_file
    local gcloud_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gcloud"
    for rule in "${_gcloud_config_rules[@]}"; do
        if [[ "$PWD" == *"${rule%%:*}"* ]]; then
            config_name="${rule#*:}"
            export CLOUDSDK_ACTIVE_CONFIG_NAME="$config_name"
            adc_file="$gcloud_dir/adc_${config_name}.json"
            if [[ -f "$adc_file" ]]; then
                export GOOGLE_APPLICATION_CREDENTIALS="$adc_file"
            else
                unset GOOGLE_APPLICATION_CREDENTIALS
            fi
            return
        fi
    done
    unset CLOUDSDK_ACTIVE_CONFIG_NAME
    unset GOOGLE_APPLICATION_CREDENTIALS
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _auto_gcloud_config

# Apply for the initial directory
_auto_gcloud_config
