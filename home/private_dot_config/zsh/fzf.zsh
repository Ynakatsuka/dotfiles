#
# Fzf Integration
#

# fzf history
function fzf-select-history() {
    BUFFER=$(history -n -r 1 | fzf --query "$LBUFFER" --reverse)
    CURSOR=$#BUFFER
    zle reset-prompt
}
zle -N fzf-select-history
bindkey '^h' fzf-select-history

# fzf git branch checkout
function fzf-git-checkout() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { zle -M "Not a git repository"; return 1; }
    local branch=$(git branch --sort=-committerdate --format='%(refname:short)' | fzf --prompt="GIT BRANCH> " --height=40% --reverse --preview='git log --oneline -20 {}')
    if [ -n "$branch" ]; then
        BUFFER="git checkout $branch"
        zle accept-line
    fi
    zle reset-prompt
}
zle -N fzf-git-checkout
bindkey '^b' fzf-git-checkout

# cdr
autoload -Uz is-at-least
if is-at-least 4.3.11
then
  autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
  add-zsh-hook chpwd chpwd_recent_dirs
  zstyle ':chpwd:*'      recent-dirs-max 500
  zstyle ':chpwd:*'      recent-dirs-default yes
  zstyle ':completion:*' recent-dirs-insert both
fi

# fzf cdr
function fzf-cdr() {
    local selected_dir=$(cdr -l | awk '{ print $2 }' | fzf --reverse)
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-cdr
setopt noflowcontrol
bindkey '^f' fzf-cdr

# fzf gcloud configuration select and login
function gcloud-fzf-activate-login() {
    local config
    config=$(gcloud config configurations list --format="value(NAME)" | fzf --prompt="GCloud Config> " --height=40% --reverse)
    if [ -n "$config" ]; then
        gcloud config configurations activate "$config"
        local login
        login=$(printf "login\nskip" | fzf --prompt="Login? > " --height=20% --reverse)
        if [ "$login" = "login" ]; then
            if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$(uname)" != "Darwin" ]; then
                gcloud auth application-default login --no-browser
            else
                gcloud auth application-default login
            fi
        fi
    fi
}
zle -N gcloud-fzf-activate-login
bindkey '^g' gcloud-fzf-activate-login

# fzf ghq repository select
function fzf-ghq-src () {
  local selected_dir=$(ghq list -p | fzf --prompt="repositories >" --query "$LBUFFER" --height=40% --reverse)
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N fzf-ghq-src
bindkey '^r' fzf-ghq-src
