#!/usr/bin/env bash
# Python CLI install method: prefer `uv tool` (fast), fall back to pipx.

pipx_install() {
  if dryrun; then would "install $1 (uv tool / pipx)"; return 0; fi

  if command -v uv >/dev/null 2>&1; then
    if uv tool list 2>/dev/null | awk '{print $1}' | grep -Fqx "$1"; then
      ok "$1 already installed; skipping"; return 0
    fi
    uv tool install "$1" || record_failure "$1" 'uv tool install failed'
    return 0
  fi

  command -v pipx >/dev/null || { record_failure "$1" 'neither uv nor pipx is available'; return 0; }
  if pipx list --short 2>/dev/null | awk '{print $1}' | grep -Fqx "$1"; then
    ok "$1 already installed; skipping"; return 0
  fi
  pipx install "$1" || record_failure "$1" 'pipx installation failed'
}

# Remove a uv/pipx-managed tool (used by `ait uninstall`).
pipx_uninstall() {
  if command -v uv >/dev/null 2>&1 && uv tool list 2>/dev/null | awk '{print $1}' | grep -Fqx "$1"; then
    uv tool uninstall "$1" || true; return 0
  fi
  command -v pipx >/dev/null && pipx uninstall "$1" || true
}
