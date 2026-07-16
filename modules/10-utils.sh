#!/usr/bin/env bash
source "$ROOT/lib/cargo.sh"
[[ "$PROFILE" == minimal ]] && return 0
log 'Installing supplementary utilities'
cargo_install rustscan || true
if is_wsl; then warn 'WSL detected: USB/mobile device passthrough needs Windows-side configuration (for example usbipd-win).'; fi
