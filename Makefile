SHELL := bash

# All first-party shell scripts. config/ snippets are sourced into interactive
# shells (bash/zsh) and are linted separately if needed.
SCRIPTS := install.sh update.sh doctor.sh uninstall.sh \
           $(wildcard lib/*.sh) $(wildcard lib/methods/*.sh) $(wildcard modules/*.sh) \
           $(wildcard scripts/*.sh) $(wildcard tests/*.sh)

.PHONY: help lint test integration readme links

help:
	@echo "make lint  - shellcheck every script"
	@echo "make test  - lint, catalog, bats, README and link checks"
	@echo "make readme - regenerate the README catalog tables"
	@echo "make links - check local Markdown links"
	@echo "make integration - resolve web/mobile profiles in a clean Ubuntu container"

readme:
	./scripts/gen-readme.sh --write

links:
	./scripts/check-links.sh

lint:
	shellcheck -x ait $(SCRIPTS)

test: lint
	@set -Eeuo pipefail; AIT_TEST_TMP=$$(mktemp -d); trap 'rm -rf -- "$$AIT_TEST_TMP"' EXIT; \
	  export BOOTSTRAP_HOME="$$AIT_TEST_TMP" YQ="$$AIT_TEST_TMP/bin/yq"; \
	  if [[ -x "$$HOME/.local/share/ait/bin/yq" ]]; then export YQ="$$HOME/.local/share/ait/bin/yq"; \
	  elif command -v yq >/dev/null 2>&1 && yq --version 2>/dev/null | grep -qi mikefarah; then export YQ="$$(command -v yq)"; fi; \
	  ./ait list --json >/dev/null; \
	  if command -v bats >/dev/null 2>&1; then bats tests/*.bats; \
	  else echo "bats not found; running shell tests directly"; \
	       bash tests/validate-catalog.sh && bash tests/resolver.sh; fi; \
	  ./scripts/gen-readme.sh --check; \
	  ./scripts/check-links.sh; \
	  bash tests/dry-run.sh

# Container smoke check for the real entrypoint and yq bootstrap. Keep the
# checkout read-only: dry-run must not alter repository files.
integration:
	@command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
	docker run --rm -v "$(CURDIR):/ait:ro" ubuntu:24.04 bash -lc \
	  'apt-get update -qq && apt-get install -y -qq bash curl ca-certificates sudo && /ait/ait install --profile web --dry-run --yes --no-shell && /ait/ait install --profile mobile --dry-run --yes --no-shell'
