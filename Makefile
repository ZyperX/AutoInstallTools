SHELL := bash

# All first-party shell scripts. config/ snippets are sourced into interactive
# shells (bash/zsh) and are linted separately if needed.
SCRIPTS := install.sh update.sh doctor.sh uninstall.sh \
           $(wildcard lib/*.sh) $(wildcard lib/methods/*.sh) $(wildcard modules/*.sh) \
           $(wildcard scripts/*.sh) $(wildcard tests/*.sh)

.PHONY: help lint test

help:
	@echo "make lint  - shellcheck every script"
	@echo "make test  - lint, validate the catalog, resolver + dry-run tests"

lint:
	@# SC1090/SC1091 are 'cannot follow source' notices, not bug checks; the
	@# dynamic module loader and runtime paths make them unavoidable here.
	shellcheck -x -e SC1090,SC1091 ait $(SCRIPTS)

test: lint
	@if command -v bats >/dev/null 2>&1; then bats tests/*.bats; \
	else echo "bats not found; running shell tests directly"; \
	     bash tests/validate-catalog.sh && bash tests/resolver.sh; fi
	bash tests/dry-run.sh
