#!/usr/bin/env bash
# shellcheck disable=SC2154  # WORDLISTS/HOME provided by the entrypoint
# Install a single catalog tool by dispatching its `method` to the matching
# install function from lib/. This is the one place that maps catalog -> methods.

# Lines of a list field (e.g. apt packages, apt_deps) for one tool.
catalog_tool_list() { N="$1" q ".tools[] | select(.name == strenv(N)) | .$2[]" "$TOOLS_YAML" 2>/dev/null; }

# Expand $WORDLISTS and a leading ~ in a catalog path (no eval on catalog data).
_expand_path() {
  local p=$1
  p=${p//\$WORDLISTS/$WORDLISTS}
  p=${p/#\~/$HOME}
  printf '%s' "$p"
}

install_tool() {
  local name=$1 method
  method=$(catalog_tool_field "$name" method)
  case "$method" in
    apt)
      local pkgs=(); mapfile -t pkgs < <(catalog_tool_list "$name" apt)
      ((${#pkgs[@]})) && apt_install "${pkgs[@]}"
      ;;
    go)
      local deps=(); mapfile -t deps < <(catalog_tool_list "$name" apt_deps)
      ((${#deps[@]})) && apt_install "${deps[@]}"
      go_install "$(catalog_tool_field "$name" go)" "$(catalog_tool_bin "$name")"
      ;;
    github_release)
      local repo dest; repo=$(catalog_tool_field "$name" repo); dest=$(catalog_tool_field "$name" dest)
      if [[ -n "$dest" ]]; then
        github_install_latest "$repo" "$(catalog_tool_bin "$name")" "$(_expand_path "$dest")"
      else
        github_install_latest "$repo" "$(catalog_tool_bin "$name")"
      fi
      ;;
    pipx) pipx_install "$(catalog_tool_field "$name" pypi)" ;;
    npm) npm_install "$(catalog_tool_field "$name" npm)" ;;
    cargo) cargo_install "$(catalog_tool_field "$name" crate)" ;;
    runtime)
      case "$(catalog_tool_field "$name" runtime)" in
        go) install_go_toolchain ;;
        rust) install_rust_toolchain ;;
        node) install_node_lts ;;
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
    git_venv | docker | official_archive | manual)
      if dryrun; then would "install $name via $method (implemented in Phase 2)"
      else record_failure "$name" "method '$method' not implemented yet (Phase 2)"; fi
      ;;
    *) record_failure "$name" "unknown install method '$method'" ;;
  esac
}
