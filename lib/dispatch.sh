#!/usr/bin/env bash
# shellcheck disable=SC2154  # WORDLISTS/HOME/BIN_DIR provided by the entrypoint
# Map a catalog tool's `method` to an installer and record it in the manifest.

# Lines of a list field (e.g. apt packages, apt_deps) for one tool.
catalog_tool_list() { N="$1" q ".tools[] | select(.name == strenv(N)) | .$2[]" "$TOOLS_YAML" 2>/dev/null; }

# Expand $WORDLISTS and a leading ~ in a catalog path (no eval on catalog data).
_expand_path() {
  local p=$1
  p=${p//\$WORDLISTS/$WORDLISTS}
  p=${p/#\~/$HOME}
  printf '%s' "$p"
}

# Methods that record their own manifest row.
_self_recording() {
  case "$1" in github_release | git_venv | docker | official_archive | manual) return 0 ;; *) return 1 ;; esac
}

# Record a generic method's install in the manifest, if it looks installed.
_record_generic() {
  local name=$1 method=$2 bin paths
  bin=$(catalog_tool_bin "$name")
  case "$method" in
    apt)   paths="apt:$(catalog_tool_list "$name" apt | paste -sd, -)" ;;
    go)    paths="$BIN_DIR/$bin,$HOME/go/bin/$bin" ;;
    pipx)  paths="pipx:$(catalog_tool_field "$name" pypi)" ;;
    npm)   paths="npm:$(catalog_tool_field "$name" npm)" ;;
    cargo) paths="cargo:$(catalog_tool_field "$name" crate)" ;;
    git | wget_mirror) paths=$(_expand_path "$(catalog_tool_field "$name" dest)") ;;
    runtime) paths="runtime:$(catalog_tool_field "$name" runtime)" ;;
    *) paths="$BIN_DIR/$bin" ;;
  esac
  manifest_add "$name" "$method" "-" "$paths"
}

install_tool() {
  local name=$1 method installed_before
  method=$(catalog_tool_field "$name" method)
  local bin; bin=$(catalog_tool_bin "$name")
  command -v "$bin" >/dev/null 2>&1 && installed_before=1 || installed_before=0

  case "$method" in
    apt)
      local pkgs=(); mapfile -t pkgs < <(catalog_tool_list "$name" apt)
      ((${#pkgs[@]})) && apt_install "${pkgs[@]}"
      ;;
    go)
      local deps=(); mapfile -t deps < <(catalog_tool_list "$name" apt_deps)
      ((${#deps[@]})) && apt_install "${deps[@]}"
      go_install "$(catalog_tool_field "$name" go)" "$bin"
      ;;
    github_release) install_github_release "$name" ;;
    pipx) pipx_install "$(catalog_tool_field "$name" pypi)" ;;
    npm) npm_install "$(catalog_tool_field "$name" npm)" ;;
    cargo) cargo_install "$(catalog_tool_field "$name" crate)" ;;
    runtime)
      case "$(catalog_tool_field "$name" runtime)" in
        go) install_go_toolchain ;;
        rust) install_rust_toolchain ;;
        node) install_node_lts ;;
        uv) install_uv_runtime ;;
        awscli) install_awscli_v2 ;;
        *) record_failure "$name" "unknown runtime" ;;
      esac
      ;;
    git)
      local url dest; url=$(catalog_tool_field "$name" git); dest=$(_expand_path "$(catalog_tool_field "$name" dest)")
      if [[ -d "$dest/.git" ]]; then ok "$name already present; skipping"
      elif dryrun; then would "git clone $url into $dest"
      else retry git clone --depth 1 "$url" "$dest" || record_failure "$name" 'clone failed'
      fi
      ;;
    wget_mirror)
      local url dest; url=$(catalog_tool_field "$name" url); dest=$(_expand_path "$(catalog_tool_field "$name" dest)")
      if [[ -d "$dest/data" ]]; then ok "$name already present; skipping (use ait update)"
      elif dryrun; then would "mirror $url into $dest (large)"
      elif ! command -v wget >/dev/null; then record_failure "$name" 'wget is required'
      else
        warn "Downloading $name (large); this can take a while."
        wget -r --no-parent -R 'index.html*' -e robots=off -nH -N -P "$dest" "$url" \
          || warn "$name mirror finished with some errors (partial lists possible)."
      fi
      ;;
    git_venv) install_git_venv "$name" ;;
    docker) install_docker_tool "$name" ;;
    official_archive) install_official_archive "$name" ;;
    manual) install_manual "$name" ;;
    *) record_failure "$name" "unknown install method '$method'" ;;
  esac

  # Record generic methods that just succeeded (self-recording methods already did).
  if ! dryrun && ! _self_recording "$method"; then
    if command -v "$bin" >/dev/null 2>&1 || { [[ "$method" == git || "$method" == wget_mirror ]] && [[ -d "$(_expand_path "$(catalog_tool_field "$name" dest)")" ]]; }; then
      _record_generic "$name" "$method"
    fi
  fi
  return 0
}
