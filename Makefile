PREFIX  ?= $(HOME)/.local
BINDIR  ?= $(PREFIX)/bin
SCRIPTS := claude-profile install.sh tests/run.sh

.DEFAULT_GOAL := help
.PHONY: help check lint test install uninstall version version-check

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check: lint version-check test ## Run everything CI runs

lint: ## Lint shell scripts with shellcheck
	shellcheck $(SCRIPTS)

test: ## Run the test suite (in a throwaway HOME)
	tests/run.sh

install: ## Install to ~/.local/bin (or PREFIX=/usr/local)
	install -d "$(BINDIR)"
	install -m 0755 claude-profile "$(BINDIR)/claude-profile"
	@echo "Installed $(BINDIR)/claude-profile"
	@echo 'Next: add  eval "$$(claude-profile shell-init)"  to ~/.zshrc or ~/.bashrc'

uninstall: ## Remove the installed script (profiles are left alone)
	rm -f "$(BINDIR)/claude-profile"

version: ## Print the version in the script
	@sed -n 's/^VERSION=//p' claude-profile

version-check: ## Fail if the plugin manifest version differs from the script
	@v=$$($(MAKE) -s version); p=$$(jq -r .version .claude-plugin/plugin.json); \
	  [ "$$v" = "$$p" ] || { echo "claude-profile VERSION=$$v but plugin.json version=$$p"; exit 1; }
