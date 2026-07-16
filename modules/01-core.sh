#!/usr/bin/env bash
source "$ROOT/lib/apt.sh"
log 'Installing core utilities'
apt_install ca-certificates curl wget gnupg lsb-release software-properties-common git build-essential unzip zip \
  jq yq tmux zoxide fzf ncdu btop htop tree ripgrep fd-find bat eza socat tcpdump tshark nmap masscan
if command -v fdfind >/dev/null; then ln -sf "$(command -v fdfind)" "$BIN_DIR/fd"; fi
if command -v batcat >/dev/null; then ln -sf "$(command -v batcat)" "$BIN_DIR/bat"; fi
