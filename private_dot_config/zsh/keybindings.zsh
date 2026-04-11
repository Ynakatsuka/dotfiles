#
# Line editor keybindings
#

# Accept next word of zsh-autosuggestions with Option+Right.
# Requires iTerm2: Settings -> Profiles -> Keys -> Left Option Key = Esc+.
# `forward-word` is in ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS by default,
# so binding it accepts one word of the gray suggestion at a time.
bindkey '^[[1;3C' forward-word   # Option+Right
bindkey '^[[1;3D' backward-word  # Option+Left
