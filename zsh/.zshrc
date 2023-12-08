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

case "$OSTYPE" in
  linux*)
    export PROMPT='%F{82}%n@%m%f:%F{63}%~%f$ '
    ;;
  *)
    export PROMPT='%F{141}%n@%m%f:%F{39}%~%f$ '
    ;;
esac

#
# Locale
#
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

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
# cuda
if [ -d "/usr/local/cuda/bin" ]; then
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
fi
# dotenv
eval "$(direnv hook zsh)"
