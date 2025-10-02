SHELL := /bin/bash

# Homebrew path setup
BREW_PREFIX := $(shell if [ -x "/opt/homebrew/bin/brew" ]; then echo "/opt/homebrew"; elif [ -x "/usr/local/bin/brew" ]; then echo "/usr/local"; fi)
export PATH := $(BREW_PREFIX)/bin:$(BREW_PREFIX)/sbin:$(PATH)

.PHONY: macos linux macos-dotfiles linux-dotfiles

# Simple entrypoints with minimal options.

macos:
	bash macos/00_xcode_brew.sh && \
	$(BREW_PREFIX)/bin/brew bundle --file macos/Brewfile && \
	bash macos/20_defaults.sh && \
	bash macos/22_pointer.sh && \
	bash macos/25_hotcorners.sh && \
	bash macos/30_iterm.sh && \
	bash macos/35_iterm_prefs.sh && \
	bash macos/10_git.sh && \
	bash macos/40_ssh.sh && \
	bash macos/45_dotfiles.sh && \
	$(BREW_PREFIX)/bin/brew cleanup

linux:
	bash linux/main.sh --with-docker --with-clis --with-cleanup

# Dotfiles-only targets

macos-dotfiles:
	bash macos/45_dotfiles.sh

linux-dotfiles:
	bash linux/modules/40_dotfiles.sh
