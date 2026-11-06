#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
source "$ROOT/lib/cargo.sh"
[[ "$PROFILE" != full ]] && return 0
log 'Installing supplementary utilities'
cargo_install rustscan || true
if is_wsl; then warn 'WSL detected: USB/mobile device passthrough needs Windows-side configuration (for example usbipd-win).'; fi
