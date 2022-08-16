# --------------------------------------------
# PROMPT
# --------------------------------------------
if [ -f git-completion.bash -a -f git-prompt.sh ]; then
  source git-completion.bash
  GIT_PS1_SHOWDIRTYSTATE=1
  source git-prompt.sh
  PS1='[\u@\h \W$(__git_ps1 " (%s)")]\$ '
fi

# --------------------------------------------
# 補完
# --------------------------------------------
# Completionファイルの読み込み
if [ -f "$USER_LOCAL/etc/bash_completion" ]; then
    source $USER_LOCAL/etc/bash_completion
fi
if [ -f $USER_LOCAL/Library/Contributions/brew_bash_completion.sh ]; then
    source $USER_LOCAL/Library/Contributions/brew_bash_completion.sh
fi

# Use bash-completion, if available
[[ $PS1 && -f /usr/share/bash-completion/bash_completion ]] && \
    . /usr/share/bash-completion/bash_completion
