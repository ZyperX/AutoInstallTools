#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR/BOOTSTRAP_HOME from lib/common.sh
# official_archive: a vendor zip/tar (or a bare .jar) extracted into
# ~/.local/share/ait/opt/<name>, with the chosen bin symlinked (or a java -jar
# wrapper written) into ~/.local/bin. Requires a pinned SHA-256 before install.
#
# Catalog keys: repo (+ asset glob) OR url; optional version, sha256 (scalar or
# per-plat map), checksum_file; bin.

install_official_archive() (
  local name=$1
  local repo asset_glob url version sha bin opt key
  repo=$(catalog_tool_field "$name" repo)
  version=$(catalog_tool_field "$name" version)
  bin=$(catalog_tool_bin "$name")
  opt="$BOOTSTRAP_HOME/opt/$name"
  key=$(plat_key || true)

  # Asset and URL may be scalars/globs or per-platform maps.
  asset_glob=''; url=''
  if [[ -n "$key" ]]; then
    asset_glob=$(catalog_tool_field "$name" "asset.$key")
    url=$(catalog_tool_field "$name" "url.$key")
  fi
  [[ -n "$asset_glob" ]] || asset_glob=$(catalog_tool_str "$name" asset)
  [[ -n "$url" ]] || url=$(catalog_tool_str "$name" url)

  command -v "$bin" >/dev/null 2>&1 && { ok "$name already installed; skipping"; return 0; }
  if dryrun; then would "install $name (official_archive)"; return 0; fi
  command -v curl >/dev/null || { record_failure "$name" 'curl required'; return 0; }

  # Pinned sha256 may be a scalar or a per-plat map. catalog_tool_str returns
  # empty for maps, so read the scalar first and only then look up the key.
  sha=$(catalog_tool_str "$name" sha256)
  if [[ -z "$sha" && -n "$key" ]]; then
    sha=$(catalog_tool_field "$name" "sha256.$key")
  fi
  local cfile; cfile=$(catalog_tool_field "$name" "checksum_file.$key")
  [[ -n "$cfile" ]] || cfile=$(catalog_tool_str "$name" checksum_file)
  if [[ -z "$sha" && -z "$cfile" ]]; then
    record_failure "$name" 'no pinned SHA-256/checksum_file; refusing unverified archive'
    return 0
  fi

  # Resolve the download URL.
  if [[ -z "$url" ]]; then
    [[ -n "$repo" && -n "$asset_glob" ]] || { record_failure "$name" 'needs url or repo+asset'; return 0; }
    local api aname
    if [[ -n "$version" ]]; then api="https://api.github.com/repos/$repo/releases/tags/$version"
    else api="https://api.github.com/repos/$repo/releases/latest"; fi
    local json; json=$(retry curl -fsSL "$api") || { record_failure "$name" 'release API query failed'; return 0; }
    # Shell-glob the asset names against asset_glob. Use process substitution,
    # not a pipeline: `jq | head` would trip pipefail via SIGPIPE.
    local n
    # shellcheck disable=SC2053  # glob match against the catalog's asset pattern
    while IFS= read -r n; do
      if [[ "$n" == $asset_glob ]]; then aname=$n; break; fi
    done < <(jq -r '.assets[].name' <<<"$json")
    [[ -n "$aname" ]] || { record_failure "$name" "no asset matching '$asset_glob'"; return 0; }
    url=$(jq -r --arg a "$aname" '.assets[] | select(.name==$a) | .browser_download_url' <<<"$json")
  fi

  local tmp; tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
  local file="$tmp/${url##*/}"
  retry curl -fL --retry 3 -o "$file" "$url" || { record_failure "$name" 'download failed'; return 0; }

  if [[ -n "$sha" ]]; then
    verify_sha256 "$file" "$sha" || { record_failure "$name" 'sha256 verification failed'; return 0; }
    ok "$name: checksum verified"
  elif [[ -n "$cfile" ]]; then
    local cfile_url; cfile_url=$(dirname "$url")/$cfile
    retry curl -fL --retry 3 -o "$tmp/cf" "$cfile_url" \
      || { record_failure "$name" 'checksum file download failed'; return 0; }
    local exp; exp=$(checksum_from_file "$tmp/cf" "${url##*/}")
    verify_sha256 "$file" "$exp" || { record_failure "$name" 'sha256 verification failed'; return 0; }
    ok "$name: checksum verified"
  else
    record_failure "$name" 'checksum verification was skipped; refusing unverified archive'
    return 0
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
    *) cp "$file" "$opt/$bin"; chmod 0755 "$opt/$bin" ;;
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
