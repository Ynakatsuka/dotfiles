#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...

#
# Prompt
#
export LSCOLORS=gxfxcxdxbxegedabagacad

#
# Language
#
export LANG=ja_JP.UTF-8
setopt print_eight_bit

#
# Alias
#
# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# docker alias
alias dc='docker compose'
alias dcps='docker compose ps'
alias dcud='docker compose up -d'
alias dcudb='docker compose up -d --build'
alias dcudf='docker compose up -d --force-recreate'
alias dce='docker compose exec $(docker compose ps --services)'
alias dcl='docker compose logs'
alias dcd='docker compose down'

#
# Path
#
# iterm2
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh" || true
# rye
source "$HOME/.rye/env"