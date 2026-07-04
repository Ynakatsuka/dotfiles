#
# Copy Last Output
#

typeset -g _LAST_CMD_FOR_COPY=""

_clo_preexec() { _LAST_CMD_FOR_COPY="$1"; }
autoload -Uz add-zsh-hook
add-zsh-hook preexec _clo_preexec

function copy_last_output() {
  if [[ -z "$_LAST_CMD_FOR_COPY" ]]; then
    echo "No previous command found."
    return 1
  fi

  # Block commands with side effects
  local unsafe_pattern='^(sudo |rm |mv |cp |curl |wget |git push|git commit|git merge|git rebase|docker rm|docker stop|kill |terraform |kubectl delete)'
  if [[ "$_LAST_CMD_FOR_COPY" =~ $unsafe_pattern ]]; then
    echo "Skipped: command may have side effects: $_LAST_CMD_FOR_COPY"
    return 1
  fi

  local output
  output=$(eval "$_LAST_CMD_FOR_COPY" 2>&1)
  local content="${_LAST_CMD_FOR_COPY}"$'\n'"${output}"
  if command -v pbcopy >/dev/null 2>&1; then
    echo "$content" | pbcopy
  elif command -v xclip >/dev/null 2>&1; then
    echo "$content" | xclip -selection clipboard
  else
    echo "No clipboard tool found."
    return 1
  fi
  echo "Copied output of: $_LAST_CMD_FOR_COPY"
}
zle -N copy_last_output
bindkey '^o' copy_last_output
