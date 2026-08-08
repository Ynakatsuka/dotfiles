SHELL := /bin/bash

OS := $(shell uname -s)
REPO_ROOT := $(abspath $(CURDIR)/..)
MISE_CONFIG := $(REPO_ROOT)/home/private_dot_config/mise/config.toml

.PHONY: full standard minimal verify

full:
ifeq ($(OS),Darwin)
	bash macos/main.sh --plan full
else ifeq ($(OS),Linux)
	bash linux/main.sh --plan full
else
	@echo "[ERROR] Unsupported OS: $(OS)" && exit 1
endif

standard:
ifeq ($(OS),Darwin)
	bash macos/main.sh --plan standard
else ifeq ($(OS),Linux)
	bash linux/main.sh --plan standard
else
	@echo "[ERROR] Unsupported OS: $(OS)" && exit 1
endif

minimal:
ifeq ($(OS),Darwin)
	bash macos/main.sh --plan minimal
else ifeq ($(OS),Linux)
	bash linux/main.sh --plan minimal
else
	@echo "[ERROR] Unsupported OS: $(OS)" && exit 1
endif

verify:
	chezmoi verify || { chezmoi status; exit 1; }
	MISE_GLOBAL_CONFIG_FILE="$(MISE_CONFIG)" mise bootstrap status -C / --missing
