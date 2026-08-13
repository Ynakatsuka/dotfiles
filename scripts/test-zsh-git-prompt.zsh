#!/usr/bin/env zsh

set -eu

repo_root=${0:A:h:h}
source "$repo_root/home/private_dot_config/zsh/prompt.zsh"

git() {
  case "$1" in
    symbolic-ref)
      print 'staging'
      ;;
    diff-index)
      [[ "${GIT_OPTIONAL_LOCKS-unset}" == '0' ]]
      ;;
    *)
      return 1
      ;;
  esac
}

prompt_info=$(git_prompt_info)
if [[ "$prompt_info" != *'%F{green}'* ]]; then
  print -u2 'prompt Git command ran without GIT_OPTIONAL_LOCKS=0'
  exit 1
fi

print 'zsh Git prompt test passed'
