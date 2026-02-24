#
# Path and Tools
#

# cache directory
[[ -d "$HOME/.zsh/cache" ]] || mkdir -p "$HOME/.zsh/cache"

# iterm2
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh" || true

# cuda
if [ -d "/usr/local/cuda/bin" ]; then
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
fi

# .local
export PATH="$HOME/.local/bin:$PATH"

# docker build
if [[ $(uname -m) == "arm64" ]]; then
  export DOCKER_DEFAULT_PLATFORM=linux/amd64
fi

# go
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# initialize runtime tools
autoload -Uz add-zsh-hook

_initialize_runtime_tools() {
  add-zsh-hook -d precmd _initialize_runtime_tools
  # rye
  if [[ -f "$HOME/.rye/env" ]]; then
    source "$HOME/.rye/env"
  fi

  # mise (--shims avoids precmd hook overhead on every Enter)
  if command -v mise > /dev/null 2>&1; then
    eval "$(mise activate zsh --shims)"
  fi

  # direnv
  if type direnv > /dev/null 2>&1; then
      eval "$(direnv hook zsh)"
  fi
}

add-zsh-hook precmd _initialize_runtime_tools
