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
