SHELL := /bin/bash
VUSTED_TREE := $(PWD)/.luarocks
VUSTED_BIN := $(VUSTED_TREE)/bin/vusted
VUSTED_ARGS := --headless --clean -u tests/vusted/init.lua

.PHONY: format format-check test ci ensure_vusted

format:
	stylua lua tests

format-check:
	stylua --check lua tests

ensure_vusted:
	@if [ ! -x "$(VUSTED_BIN)" ]; then \
		echo "Installing vusted locally into $(VUSTED_TREE)"; \
		luarocks --lua-version=5.1 --tree "$(VUSTED_TREE)" install vusted; \
	fi

test: ensure_vusted
	PATH="$(VUSTED_TREE)/bin:$$PATH" \
	CMT_VUSTED_ROCKS="$(VUSTED_TREE)" \
	VUSTED_ARGS="$(VUSTED_ARGS)" \
	"$(VUSTED_BIN)" lua/cmt/tests

ci: format-check test
