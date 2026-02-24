#
# Prompt
#
export LSCOLORS=gxfxcxdxbxegedabagacad

# Enable $EPOCHSECONDS and command substitution in prompts
zmodload zsh/datetime
setopt PROMPT_SUBST

# Google Cloud config info for prompt
gcloud_prompt_info() {
  local config_path="$HOME/.config/gcloud/active_config"
  [[ -r "$config_path" ]] || return
  local config
  config=$(<"$config_path") || return
  config=${config//$'\n'/}
  [[ -n "$config" ]] && print " [%F{220}$config%f]"
}

# Git branch info for prompt (with cache + fast diff-index)
typeset -g _git_prompt_cache=""
typeset -g _git_prompt_cache_time=0
typeset -g _git_prompt_cache_dir=""

git_prompt_info() {
  local now=$EPOCHSECONDS
  # Return cache if within 2 seconds and same directory
  if (( now - _git_prompt_cache_time < 2 )) && [[ "$PWD" == "$_git_prompt_cache_dir" ]]; then
    [[ -n "$_git_prompt_cache" ]] && print "$_git_prompt_cache"
    return
  fi

  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || {
    _git_prompt_cache=""
    _git_prompt_cache_time=$now
    _git_prompt_cache_dir="$PWD"
    return
  }

  local color="green"
  # diff-index is significantly faster than status --porcelain
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    color="yellow"
  fi

  _git_prompt_cache=" %F{${color}}🌿 ${branch}%f"
  _git_prompt_cache_time=$now
  _git_prompt_cache_dir="$PWD"
  print "$_git_prompt_cache"
}

# Use zsh built-in %(5~|~/.../%3~|%~) for truncated path (no fork)
case "$OSTYPE" in
  linux*)
    export PROMPT='%F{82}%n@%m%f:%F{63}%(5~|~/.../%3~|%~)%f$(git_prompt_info)$(gcloud_prompt_info)$ '
    ;;
  *)
    export PROMPT='%F{141}%n@%m%f:%F{39}%(5~|~/.../%3~|%~)%f$(git_prompt_info)$(gcloud_prompt_info)$ '
    ;;
esac
