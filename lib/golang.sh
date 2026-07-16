#!/usr/bin/env bash
go_install(){
  local package=$1 binary=${2:-${package##*/}}
  command -v "$binary" >/dev/null 2>&1 && { ok "$binary already installed; skipping"; return 0; }
  command -v go >/dev/null || { record_failure "$binary" 'Go is unavailable'; return 0; }
  retry go install "$package@latest" || { record_failure "$binary" 'go install failed'; return 0; }
  [[ -x "$HOME/go/bin/$binary" ]] && ln -sf "$HOME/go/bin/$binary" "$BIN_DIR/$binary" || record_failure "$binary" 'binary was not produced by go install'
}
