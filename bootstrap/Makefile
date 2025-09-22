SHELL := /bin/bash

.PHONY: macos linux macos-dotfiles linux-dotfiles

# Simple entrypoints with minimal options.

macos:
	bash macos/00_xcode_brew.sh && \
	brew bundle --file macos/Brewfile && \
	bash macos/20_defaults.sh && \
	bash macos/22_pointer.sh && \
	bash macos/25_hotcorners.sh && \
	bash macos/30_iterm.sh && \
	bash macos/35_iterm_prefs.sh && \
	bash macos/10_git.sh && \
	bash macos/40_ssh.sh && \
	bash macos/45_dotfiles.sh && \
	brew cleanup

linux:
	bash linux/main.sh --with-docker --with-clis --with-cleanup

# Dotfiles-only targets

macos-dotfiles:
	bash macos/45_dotfiles.sh

linux-dotfiles:
	bash linux/modules/40_dotfiles.sh
