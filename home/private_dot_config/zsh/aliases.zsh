#
# Alias
#

# eza aliases (modern ls replacement)
alias ll='eza --icons -al --group-directories-first'
alias la='eza --icons -a --group-directories-first'
alias l='eza --icons --group-directories-first'
alias tree='eza --icons -al -T -L 2'

# process management
alias fkill='ps aux | fzf --height=40% --reverse | awk "{print \$2}" | xargs kill -9'

# reload current zsh session with a fresh process
alias reload='exec zsh'

# docker (fzf-driven helpers — abbreviations live in abbr.zsh)
alias de='docker exec -it $(docker ps | fzf | awk "{print \$1}") /bin/bash'

unalias dce 2>/dev/null
dce() {
  local service
  service=$(docker compose ps --services 2>/dev/null | fzf --prompt="Service> " --height=40% --reverse)
  if [[ -n "$service" ]]; then
    docker compose exec "$service" "${@:-/bin/bash}"
  fi
}

#
# Git
#

# git checkout lb
alias -g lb='`git branch | fzf --prompt="GIT BRANCH> " --height=40% --reverse | head -n 1 | sed -e "s/^\*\s*//g"`'

# Git utilities
alias gco='git checkout $(git branch --sort=-committerdate | fzf --height=40% --reverse)'
