#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/golang.sh"; source "$ROOT/lib/pipx.sh"; source "$ROOT/lib/github.sh"
[[ "$PROFILE" != full ]] && return 0
log 'Installing web testing tools'
apt_install sqlmap gobuster
# feroxbuster is not in stock apt; use its release binary (B6).
github_install_latest epi052/feroxbuster feroxbuster || true
go_install github.com/ffuf/ffuf/v2 ffuf || true
go_install github.com/hahwul/dalfox/v2 dalfox || true
# Arjun is a Python tool, not Go (B1).
pipx_install arjun || true
pipx_install dirsearch || true
# XSStrike, tplmap, commix, jwt-tool, SSRFmap, Corsy and CRLFuzz vary in packaging;
# they move into catalog/tools.yaml in a later phase.
