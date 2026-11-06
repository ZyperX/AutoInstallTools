#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR is provided by lib/common.sh
# Go toolchain + `go install` method.
#
# Ubuntu/Debian ship an old Go (22.04 = 1.18) that cannot build current
# ProjectDiscovery tools, so install the official tarball into user space and
# let GOTOOLCHAIN=auto fetch a newer toolchain when a module demands it (B2).

_go_arch() {
  case "$(uname -m)" in
    x86_64) echo amd64 ;;
    aarch64 | arm64) echo arm64 ;;
    *) return 1 ;;
  esac
}

# True when a usable Go (>= 1.21) is already on PATH.
_go_recent_enough() {
  local v
  v=$(go version 2>/dev/null | grep -oE 'go[0-9]+\.[0-9]+' | head -n1) || return 1
  v=${v#go}
  local major=${v%%.*} minor=${v#*.}
  ((major > 1)) || { ((major == 1)) && ((minor >= 21)); }
}

install_go_toolchain() {
  if command -v go >/dev/null 2>&1 && _go_recent_enough; then
    ok "Go $(go version | awk '{print $3}') already present; skipping"
    return 0
  fi

  # Short-circuit before any dependency or network access so --dry-run is truthful.
  if dryrun; then would "install the latest stable Go to $HOME/.local/go"; return 0; fi

  local arch
  arch=$(_go_arch) || { record_failure 'go' "unsupported CPU architecture $(uname -m)"; return 0; }

  command -v curl >/dev/null && command -v jq >/dev/null || {
    record_failure 'go' 'curl and jq are required to install Go'; return 0; }

  # go.dev publishes a machine-readable index with per-file sha256 checksums.
  local index file sha
  index=$(retry curl -fsSL 'https://go.dev/dl/?mode=json') || {
    record_failure 'go' 'could not query the Go download index'; return 0; }
  file=$(jq -r --arg a "$arch" \
    'map(select(.stable))[0].files[] | select(.os=="linux" and .arch==$a and .kind=="archive") | .filename' \
    <<<"$index" | head -n1)
  sha=$(jq -r --arg f "$file" \
    'map(select(.stable))[0].files[] | select(.filename==$f) | .sha256' <<<"$index" | head -n1)
  [[ -n "$file" && -n "$sha" && "$sha" != null ]] || {
    record_failure 'go' 'no stable Go release found for this platform'; return 0; }

  local tmp; tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' RETURN
  retry curl -fL --retry 3 -o "$tmp/go.tgz" "https://go.dev/dl/$file" || {
    record_failure 'go' 'Go tarball download failed'; return 0; }
  echo "$sha  $tmp/go.tgz" | sha256sum -c - >/dev/null 2>&1 || {
    record_failure 'go' 'Go tarball checksum verification failed'; return 0; }

  rm -rf -- "$HOME/.local/go"
  mkdir -p "$HOME/.local"
  tar -C "$HOME/.local" -xzf "$tmp/go.tgz" || {
    record_failure 'go' 'could not extract the Go tarball'; return 0; }
  ln -sf "$HOME/.local/go/bin/go" "$BIN_DIR/go"
  ln -sf "$HOME/.local/go/bin/gofmt" "$BIN_DIR/gofmt"
  ok "Installed $("$HOME/.local/go/bin/go" version | awk '{print $3}')"
}

go_install() {
  local package=$1 binary=${2:-${package##*/}}
  command -v "$binary" >/dev/null 2>&1 && { ok "$binary already installed; skipping"; return 0; }
  if dryrun; then would "go install $package@latest"; return 0; fi
  command -v go >/dev/null || { record_failure "$binary" 'Go is unavailable'; return 0; }
  retry go install "$package@latest" || { record_failure "$binary" 'go install failed'; return 0; }
  if [[ -x "$HOME/go/bin/$binary" ]]; then
    ln -sf "$HOME/go/bin/$binary" "$BIN_DIR/$binary"
  else
    record_failure "$binary" 'binary was not produced by go install'
  fi
}
