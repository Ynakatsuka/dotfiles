#
# Path and Tools
#

# CUDA PATH stays here (interactive-only) because it is hardware-dependent:
# it must be skipped on CPU-only machines and non-interactive shells alike.
if [[ -d "/usr/local/cuda/bin" ]]; then
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# Older mise versions do not support settings.task.run_auto_install.
if command -v mise > /dev/null 2>&1; then
  mise() {
    local arg task=""
    if [[ "$1" == "maintenance" || "$1" == "update-dotfiles" ]]; then
      task=$1
    elif [[ "$1" == "run" || "$1" == "r" ]]; then
      for arg in "$@"; do
        if [[ "$arg" == "maintenance" || "$arg" == "update-dotfiles" ]]; then
          task=$arg
          break
        fi
      done
    fi

    if [[ -z "$task" ]]; then
      command mise "$@"
      return
    fi
    MISE_TASK_RUN_AUTO_INSTALL=false command mise "$@" || return
    # maintenance replaces shell config and tools, so restart into them. Help
    # output runs nothing, and agent shells replay this function and must keep
    # their process.
    local help_args="${(M)@:#(-h|--help)}"
    if [[ "$task" == "maintenance" && -z "$help_args" && -o interactive && -t 0 && -t 1 && -z "$CLAUDECODE" ]]; then
      exec zsh
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

  # direnv
  if type direnv > /dev/null 2>&1; then
      eval "$(direnv hook zsh)"
  fi
}

add-zsh-hook precmd _initialize_runtime_tools
