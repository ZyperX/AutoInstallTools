#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR from lib/common.sh
# uv: Astral's fast Python package/tool manager.
#
# The `uv` install method installs a PyPI tool into its own uv-managed
# environment, falling back to pipx when uv is unavailable. uv itself is
# installed from its GitHub release (checksum-verified by the release helper),
# never with curl | bash.

install_uv_runtime() {
  if command -v uv >/dev/null 2>&1; then ok "uv already present; skipping"; return 0; fi
  if dryrun; then would 'install uv from the astral-sh/uv release'; return 0; fi
  github_install_latest astral-sh/uv uv
}

# install_uv_tool <tool-name> <pypi-name> <binary-name>
install_uv_tool() {
  local name=$1 pypi=$2 bin=$3 version spec
  [[ -n "$pypi" ]] || { record_failure "$name" 'uv method needs pypi'; return 0; }
  # A catalog `version` pins the PyPI package (e.g. the frida-tools/objection pair).
  version=$(catalog_tool_field "$name" version)
  spec=$pypi
  [[ -n "$version" ]] && spec="$pypi==$version"
  if [[ ${FORCE_INSTALL:-0} != 1 ]] && command -v "$bin" >/dev/null 2>&1; then
    ok "$bin already installed; skipping"
    return 0
  fi
  if dryrun; then
    would "uv tool install $spec (pipx fallback) and record $BIN_DIR/$bin"
    return 0
  fi

  if command -v uv >/dev/null 2>&1; then
    if [[ ${FORCE_INSTALL:-0} == 1 ]]; then
      retry uv tool install --upgrade "$spec" || { record_failure "$name" "uv tool install failed"; return 0; }
    else
      retry uv tool install "$spec" || { record_failure "$name" "uv tool install failed"; return 0; }
    fi
    # uv puts tools in ~/.local/bin already; make the link explicit for older uv.
    if ! command -v "$bin" >/dev/null 2>&1; then
      local found; found=$(find "$HOME/.local/share/uv/tools" -type f -name "$bin" 2>/dev/null | head -n1)
      [[ -n "$found" ]] && ln -sf "$found" "$BIN_DIR/$bin"
    fi
    command -v "$bin" >/dev/null 2>&1 || { record_failure "$name" 'uv did not produce the expected command'; return 0; }
    manifest_add "$name" uv "${version:--}" "uv:$pypi"
    ok "Installed $bin (uv: $spec)"
    return 0
  fi

  warn "$bin: uv is unavailable; falling back to pipx"
  command -v pipx >/dev/null 2>&1 || { record_failure "$name" 'neither uv nor pipx is available'; return 0; }
  pipx_install "$spec" || { record_failure "$name" 'pipx install failed'; return 0; }
  manifest_add "$name" pipx "${version:--}" "pipx:$pypi"
}
