SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

BATS ?= bats
BATS_FLAGS ?=
DOCKER ?= docker
LINUX_IMAGE := scripts-test-linux
SH_FILES := $(wildcard *.sh)

.PHONY: help test test-macos test-linux test-windows test-network docker-image lint check clean

help: ## List available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

test: ## Run the bats suite on this machine (needs bash >= 4.4, bats, yq, jq, perl)
	$(BATS) $(BATS_FLAGS) tests

test-macos: test ## Alias for test on macOS (install deps: brew install bats-core yq jq)

test-linux: docker-image ## Run the suite in a pinned Debian container
	$(DOCKER) run --rm -v "$(CURDIR)":/work:ro -w /work $(LINUX_IMAGE) bats $(BATS_FLAGS) tests

test-windows: ## On Windows run the suite via Git Bash or WSL; explains itself elsewhere
ifneq (,$(findstring NT,$(shell uname -s)))
	$(BATS) $(BATS_FLAGS) tests
else
	@echo "Windows cannot be emulated from $(shell uname -s)."
	@echo "On a Windows machine install Git Bash (or WSL) plus bats-core, yq, jq, then run: make test"
	@exit 1
endif

test-network: ## Run the suite including keyserver tests (needs internet)
	RUN_NETWORK_TESTS=1 $(BATS) $(BATS_FLAGS) tests

docker-image: ## Build the Linux test image (cached)
	$(DOCKER) build -t $(LINUX_IMAGE) tests

lint: ## shellcheck all library files (local shellcheck, else docker)
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck $(SH_FILES); \
	else \
	  $(DOCKER) run --rm -v "$(CURDIR)":/mnt:ro koalaman/shellcheck:stable $(SH_FILES); \
	fi

check: lint test ## Lint, then run the suite

clean: ## Remove the Linux test image
	-$(DOCKER) rmi $(LINUX_IMAGE) 2>/dev/null || true
