#!/usr/bin/env bash
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/golang.sh"; source "$ROOT/lib/pipx.sh"
[[ "$PROFILE" == minimal ]] && return 0
log 'Installing web testing tools'
apt_install sqlmap gobuster feroxbuster
go_install github.com/ffuf/ffuf/v2 ffuf || true
go_install github.com/hahwul/dalfox/v2 dalfox || true
go_install github.com/s0md3v/Arjun arjun || true
pipx_install dirsearch || true
# XSStrike, tplmap, commix, jwt-tool, SSRFmap, Corsy and CRLFuzz vary in packaging;
# install them from their upstream repositories after reviewing their dependencies.
