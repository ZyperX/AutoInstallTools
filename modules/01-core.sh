#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/github.sh"
log 'Installing core utilities'
# yq (mikefarah) and eza are not reliably packaged on supported releases, so
# they come from upstream release binaries instead of apt (B6).
apt_install ca-certificates curl wget gnupg lsb-release software-properties-common git build-essential unzip zip \
  jq tmux zoxide fzf ncdu btop htop tree ripgrep fd-find bat socat tcpdump tshark nmap masscan
github_install_latest mikefarah/yq yq || true
github_install_latest eza-community/eza eza || true
# Debian renames these binaries; expose the conventional names in user bin.
if ! dryrun && command -v fdfind >/dev/null; then ln -sf "$(command -v fdfind)" "$BIN_DIR/fd"; fi
if ! dryrun && command -v batcat >/dev/null; then ln -sf "$(command -v batcat)" "$BIN_DIR/bat"; fi
