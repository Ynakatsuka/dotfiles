#
# Line editor keybindings
#

# Accept next word of zsh-autosuggestions with Option+Right.
# Requires a terminal profile that sends Esc+ for Option.
# `forward-word` is in ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS by default,
# so binding it accepts one word of the gray suggestion at a time.
bindkey '^[[1;3C' forward-word   # Option+Right
bindkey '^[[1;3D' backward-word  # Option+Left
