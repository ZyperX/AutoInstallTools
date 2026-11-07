#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR/BOOTSTRAP_HOME from lib/common.sh
# official_archive: a vendor zip/tar (or a bare .jar) extracted into
# ~/.local/share/ait/opt/<name>, with the chosen bin symlinked (or a java -jar
# wrapper written) into ~/.local/bin. Verifies sha256 when the catalog pins it.
#
# Catalog keys: repo (+ asset glob) OR url; optional version, sha256 (scalar or
# per-plat map), checksum_file; bin.

install_official_archive() (
  local name=$1
  local repo asset_glob url version sha bin opt key
  repo=$(catalog_tool_field "$name" repo)
  asset_glob=$(catalog_tool_field "$name" asset)
  url=$(catalog_tool_field "$name" url)
  version=$(catalog_tool_field "$name" version)
  bin=$(catalog_tool_bin "$name")
  opt="$BOOTSTRAP_HOME/opt/$name"
  key=$(plat_key || true)

  command -v "$bin" >/dev/null 2>&1 && { ok "$name already installed; skipping"; return 0; }
  if dryrun; then would "install $name (official_archive)"; return 0; fi
  command -v curl >/dev/null || { record_failure "$name" 'curl required'; return 0; }

  # pinned sha256 may be a scalar or a per-plat map
  sha=$(catalog_tool_field "$name" sha256)
  [[ -z "$sha" && -n "$key" ]] && sha=$(catalog_tool_field "$name" "sha256.$key")

  # Resolve the download URL.
  if [[ -z "$url" ]]; then
    [[ -n "$repo" && -n "$asset_glob" ]] || { record_failure "$name" 'needs url or repo+asset'; return 0; }
    local api aname
    if [[ -n "$version" ]]; then api="https://api.github.com/repos/$repo/releases/tags/$version"
    else api="https://api.github.com/repos/$repo/releases/latest"; fi
    local json; json=$(retry curl -fsSL "$api") || { record_failure "$name" 'release API query failed'; return 0; }
    # shell-glob the asset names against asset_glob
    # shellcheck disable=SC2053  # glob match against the catalog's asset pattern
    aname=$(jq -r '.assets[].name' <<<"$json" | while IFS= read -r n; do [[ "$n" == $asset_glob ]] && echo "$n"; done | head -n1)
    [[ -n "$aname" ]] || { record_failure "$name" "no asset matching '$asset_glob'"; return 0; }
    url=$(jq -r --arg a "$aname" '.assets[] | select(.name==$a) | .browser_download_url' <<<"$json")
  fi

  local tmp; tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
  local file="$tmp/${url##*/}"
  retry curl -fL --retry 3 -o "$file" "$url" || { record_failure "$name" 'download failed'; return 0; }

  if [[ -n "$sha" ]]; then
    verify_sha256 "$file" "$sha" || { record_failure "$name" 'sha256 verification failed'; return 0; }
    ok "$name: checksum verified"
  else
    warn "$name: no pinned checksum; installing unpinned"
  fi

  rm -rf -- "$opt"; mkdir -p "$opt"
  case "$file" in
    *.jar)
      cp "$file" "$opt/$name.jar"
      cat > "$BIN_DIR/$bin" <<EOF
#!/usr/bin/env bash
exec java -jar "$opt/$name.jar" "\$@"
EOF
      chmod 0755 "$BIN_DIR/$bin"
      ;;
    *.zip) unzip -q "$file" -d "$opt" || { record_failure "$name" 'unzip failed'; return 0; } ;;
    *.tar.gz | *.tgz) tar -xzf "$file" -C "$opt" || { record_failure "$name" 'extract failed'; return 0; } ;;
    *.tar.xz) tar -xJf "$file" -C "$opt" || { record_failure "$name" 'extract failed'; return 0; } ;;
    *) cp "$file" "$opt/$bin" ;;
  esac

  # For archives, find the requested bin inside and symlink it (launchers
  # resolve their own dir via the symlink target).
  if [[ ! -e "$BIN_DIR/$bin" ]]; then
    local found; found=$(find "$opt" -type f -name "$bin" | head -n1)
    [[ -n "$found" ]] || { record_failure "$name" "could not find '$bin' in archive"; return 0; }
    chmod +x "$found" 2>/dev/null || true
    ln -sf "$found" "$BIN_DIR/$bin"
  fi

  manifest_add "$name" official_archive "${version:--}" "$opt,$BIN_DIR/$bin"
  ok "Installed $name"
)
