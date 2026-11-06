#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/pipx.sh"
[[ "$PROFILE" != mobile && "$PROFILE" != full ]] && return 0
log 'Installing Android/mobile essentials'
# jadx and dex2jar are not in stock apt and ship as launcher archives, not
# single binaries; they move to catalog/tools.yaml (github_release) in Phase 3.
apt_install adb fastboot apktool
pipx_install objection || true
pipx_install frida-tools || true
warn 'iOS tooling needs macOS or a compatible Linux environment; bagbak, ipsw and drozer are intentionally not auto-installed.'
