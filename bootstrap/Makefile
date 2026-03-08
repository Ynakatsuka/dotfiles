SHELL := /bin/bash

OS := $(shell uname -s)

.PHONY: full standard minimal

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
