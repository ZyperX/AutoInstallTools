#!/usr/bin/env bash
# pipx install method for Python CLI tools. (uv becomes the primary in Phase 2.)

pipx_install() {
  if dryrun; then would "pipx install $1"; return 0; fi
  command -v pipx >/dev/null || { record_failure "$1" 'pipx is unavailable'; return 0; }
  if pipx list --short 2>/dev/null | awk '{print $1}' | grep -Fqx "$1"; then
    ok "$1 already installed; skipping"
    return 0
  fi
  pipx install "$1" || record_failure "$1" 'pipx installation failed'
}
