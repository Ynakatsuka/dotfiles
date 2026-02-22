#
# Prompt
#
export LSCOLORS=gxfxcxdxbxegedabagacad

# Google Cloud config info for prompt
setopt PROMPT_SUBST  # Enable command substitution in prompts

gcloud_prompt_info() {
  local config_path="$HOME/.config/gcloud/active_config"
  [[ -r "$config_path" ]] || return
  local config
  config=$(<"$config_path") || return
  config=${config//$'\n'/}
  [[ -n "$config" ]] && print " [%F{220}$config%f]"
}

# Git branch info for prompt
git_prompt_info() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
  local color="green"
  if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
    color="yellow"
  fi
  print " %F{${color}}🌿 ${branch}%f"
}

# Fast custom prompt function to show truncated path with ellipsis
custom_pwd() {
  local pwd_length=3  # Number of directories to show
  local current_dir="$PWD"

  # Replace home directory with ~
  if [[ "$current_dir" == "$HOME"* ]]; then
    current_dir="~${current_dir#$HOME}"
  fi

  # Split path into array using zsh built-in
  local -a path_parts
  path_parts=(${(s:/:)current_dir})

  # If path is short enough, return as is
  if (( ${#path_parts} <= $((pwd_length + 1)) )); then
    echo "$current_dir"
  else
    # Take last pwd_length parts using zsh array slicing
    local short_path="${(j:/:)path_parts[-$pwd_length,-1]}"
    echo "~/.../$short_path"
  fi
}

case "$OSTYPE" in
  linux*)
    export PROMPT='%F{82}%n@%m%f:%F{63}$(custom_pwd)%f$(git_prompt_info)$(gcloud_prompt_info)$ '
    ;;
  *)
    export PROMPT='%F{141}%n@%m%f:%F{39}$(custom_pwd)%f$(git_prompt_info)$(gcloud_prompt_info)$ '
    ;;
esac
