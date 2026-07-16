#!/usr/bin/env bash
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/pipx.sh"
[[ "$PROFILE" != mobile && "$PROFILE" != full ]] && return 0
log 'Installing Android/mobile essentials'
apt_install adb fastboot apktool jadx dex2jar
pipx_install objection || true
pipx_install frida-tools || true
warn 'iOS tooling needs macOS or a compatible Linux environment; bagbak, ipsw and drozer are intentionally not auto-installed.'
