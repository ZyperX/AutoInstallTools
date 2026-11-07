#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR from lib/common.sh
# uv: Astral's fast Python package/tool manager. Installed from its GitHub
# release (checksum-verified by the github_release method) rather than curl|bash.
install_uv_runtime() {
  if command -v uv >/dev/null 2>&1; then ok "uv already present; skipping"; return 0; fi
  if dryrun; then would 'install uv from the astral-sh/uv release'; return 0; fi
  github_install_latest astral-sh/uv uv
  # uv ships uvx alongside uv; symlink it too if present in the same release.
  [[ -x "$BIN_DIR/uvx" ]] || command -v uvx >/dev/null 2>&1 || true
}
