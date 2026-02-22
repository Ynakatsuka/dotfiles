SHELL := /bin/bash

.PHONY: macos linux macos-dotfiles linux-dotfiles

macos:
	bash macos/00_xcode_brew.sh
	@BREW=$$(if [ -x "/opt/homebrew/bin/brew" ]; then echo "/opt/homebrew/bin/brew"; elif [ -x "/usr/local/bin/brew" ]; then echo "/usr/local/bin/brew"; else echo "brew"; fi) && \
	$$BREW bundle --file macos/Brewfile && \
	bash macos/20_defaults.sh && \
	bash macos/22_pointer.sh && \
	bash macos/25_hotcorners.sh && \
	bash macos/30_iterm.sh && \
	bash macos/35_iterm_prefs.sh && \
	bash macos/10_git.sh && \
	bash macos/40_ssh.sh && \
	bash macos/45_dotfiles.sh && \
	$$BREW cleanup

linux:
	bash linux/main.sh --with-docker --with-clis --with-cleanup

macos-dotfiles:
	bash macos/45_dotfiles.sh

linux-dotfiles:
	bash linux/modules/40_dotfiles.sh
