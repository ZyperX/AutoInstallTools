#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR from lib/common.sh
# github_release: install a release binary. If the catalog pins `version` +
# `asset` (+ `sha256`/`checksum_file`) for this platform, download that exact
# asset and verify it; otherwise fall back to the unpinned latest with a warning.

install_github_release() (
  local name=$1 repo bin dest version key asset sha cfile
  repo=$(catalog_tool_field "$name" repo)
  bin=$(catalog_tool_bin "$name")
  dest=$(catalog_tool_field "$name" dest); dest=$(_expand_path "${dest:-$BIN_DIR/$bin}")
  version=$(catalog_tool_field "$name" version)
  key=$(plat_key || true)

  [[ ${FORCE_INSTALL:-0} == 1 ]] || ! command -v "$bin" >/dev/null 2>&1 || { ok "$name already installed; skipping"; return 0; }
  if dryrun; then would "install $name from $repo (${version:-latest})"; return 0; fi

  if [[ -z "$version" ]]; then
    record_failure "$name" 'catalog release must pin a version and verified checksum'
    return 0
  fi

  asset=$(catalog_tool_field "$name" "asset.$key")
  sha=$(catalog_tool_field "$name" "sha256.$key")
  cfile=$(catalog_tool_field "$name" checksum_file)
  [[ -n "$asset" ]] || { record_failure "$name" "no pinned asset for $key"; return 0; }
  if [[ -z "$sha" && -z "$cfile" ]]; then
    record_failure "$name" "no pinned SHA-256/checksum_file for $key; refusing unverified release"
    return 0
  fi

  local tmp; tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
  local url="https://github.com/$repo/releases/download/$version/$asset"
  retry curl -fL --retry 3 -o "$tmp/asset" "$url" || { record_failure "$name" 'download failed'; return 0; }

  if [[ -n "$sha" ]]; then
    verify_sha256 "$tmp/asset" "$sha" || { record_failure "$name" 'sha256 verification failed'; return 0; }
    ok "$name: checksum verified"
  elif [[ -n "$cfile" ]]; then
    retry curl -fL --retry 3 -o "$tmp/cf" "https://github.com/$repo/releases/download/$version/$cfile" \
      || { record_failure "$name" 'checksum file download failed'; return 0; }
    local exp; exp=$(checksum_from_file "$tmp/cf" "$asset")
    verify_sha256 "$tmp/asset" "$exp" || { record_failure "$name" 'sha256 verification failed'; return 0; }
    ok "$name: checksum verified"
  else
    record_failure "$name" 'checksum verification was skipped; refusing unverified release'
    return 0
  fi

  gh_install_from_file "$tmp/asset" "$asset" "$bin" "$dest" || return 0
  manifest_add "$name" github_release "$version" "$dest"
  ok "Installed $name ($version)"
)
