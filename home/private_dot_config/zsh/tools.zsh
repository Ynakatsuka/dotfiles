#
# Path and Tools
#

# cache directory
[[ -d "$HOME/.zsh/cache" ]] || mkdir -p "$HOME/.zsh/cache"

# CUDA PATH stays here (interactive-only) because it is hardware-dependent:
# it must be skipped on CPU-only machines and non-interactive shells alike.
if [ -d "/usr/local/cuda/bin" ]; then
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
fi

# $HOME/.local/bin and GOPATH/bin are set in dot_zshenv for non-interactive shells.
# GOPATH is re-exported here so interactive subprocesses pick it up if zshenv
# was somehow skipped (e.g. nested zsh with --no-rcs).
export GOPATH="$HOME/go"

# Older mise versions do not support settings.task.run_auto_install.
if command -v mise > /dev/null 2>&1; then
  mise() {
    local arg skip_auto_install=0
    if [[ "$1" == "maintenance" || "$1" == "update-dotfiles" ]]; then
      skip_auto_install=1
    elif [[ "$1" == "run" || "$1" == "r" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == "maintenance" || "$arg" == "update-dotfiles" ]]; then
          skip_auto_install=1
          break
        fi
      done
    fi

    if (( skip_auto_install )); then
      MISE_TASK_RUN_AUTO_INSTALL=false command mise "$@"
    else
      command mise "$@"
    fi
  }
fi

# docker build
if [[ $(uname -m) == "arm64" ]]; then
  export DOCKER_DEFAULT_PLATFORM=linux/amd64
fi

# initialize runtime tools
autoload -Uz add-zsh-hook

_initialize_runtime_tools() {
  add-zsh-hook -d precmd _initialize_runtime_tools

  # mise (--shims avoids precmd hook overhead on every Enter)
  if command -v mise > /dev/null 2>&1; then
    eval "$(command mise activate zsh --shims)"
  fi

  # direnv
  if type direnv > /dev/null 2>&1; then
      eval "$(direnv hook zsh)"
  fi
}

add-zsh-hook precmd _initialize_runtime_tools
