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

# docker alias
alias dc='docker compose'
alias dcps='docker compose ps'
alias dcud='docker compose up -d'
alias dcudb='docker compose up -d --build'
alias dcudf='docker compose up -d --force-recreate'
alias dcl='docker compose logs'
alias dcd='docker compose down'
alias de='docker exec -it $(docker ps | fzf | awk "{print \$1}") /bin/bash'

unalias dce 2>/dev/null
dce() {
  local service
  service=$(docker compose ps --services 2>/dev/null | fzf --prompt="Service> " --height=40% --reverse)
  if [[ -n "$service" ]]; then
    docker compose exec "$service" "${@:-/bin/bash}"
  fi
}

# gcloud
alias gca='gcloud config configurations activate'
alias gcl='gcloud config configurations list'
alias gal='gcloud auth application-default login'
alias gcsp='gcloud config set project'

# codex
alias co='codex'

#
# Git
#

# git checkout lb
alias -g lb='`git branch | fzf --prompt="GIT BRANCH> " --height=40% --reverse | head -n 1 | sed -e "s/^\*\s*//g"`'

# Git worktree
alias gwt='git worktree'
alias gwta='git worktree add'
alias gwtl='git worktree list'
alias gwtr='git worktree remove'

# Git utilities
alias gco='git checkout $(git branch --sort=-committerdate | fzf --height=40% --reverse)'
alias ghopen='gh repo view --web'
