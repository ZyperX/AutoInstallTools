#!/usr/bin/env bash
# Rust toolchain (rustup) + `cargo install` method.
#
# apt rustc/cargo are too old for many current crates, so install rustup from
# the official, checksum-verified rustup-init binary into user space (B2). This
# avoids piping a remote script straight into a shell.

_rust_target() {
  case "$(uname -m)" in
    x86_64) echo x86_64-unknown-linux-gnu ;;
    aarch64 | arm64) echo aarch64-unknown-linux-gnu ;;
    *) return 1 ;;
  esac
}

# Subshell function so the tmp-cleanup EXIT trap cannot leak to other returns.
install_rust_toolchain() (
  if command -v rustup >/dev/null 2>&1; then
    ok "rustup already present; skipping"
    return 0
  fi

  # Short-circuit before any dependency or network access so --dry-run is truthful.
  if dryrun; then would 'install rustup and the stable Rust toolchain'; return 0; fi

  local target
  target=$(_rust_target) || { record_failure 'rust' "unsupported CPU architecture $(uname -m)"; return 0; }
  command -v curl >/dev/null || { record_failure 'rust' 'curl is required to install rustup'; return 0; }

  local base="https://static.rust-lang.org/rustup/dist/$target"
  local tmp; tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
  retry curl -fL --retry 3 -o "$tmp/rustup-init" "$base/rustup-init" || {
    record_failure 'rust' 'rustup-init download failed'; return 0; }
  retry curl -fL --retry 3 -o "$tmp/rustup-init.sha256" "$base/rustup-init.sha256" || {
    record_failure 'rust' 'rustup-init checksum download failed'; return 0; }

  local expected actual
  expected=$(awk '{print $1}' "$tmp/rustup-init.sha256")
  actual=$(sha256sum "$tmp/rustup-init" | awk '{print $1}')
  [[ -n "$expected" && "$expected" == "$actual" ]] || {
    record_failure 'rust' 'rustup-init checksum verification failed'; return 0; }

  chmod +x "$tmp/rustup-init"
  "$tmp/rustup-init" -y --no-modify-path --profile minimal || {
    record_failure 'rust' 'rustup installation failed'; return 0; }
  ok "Installed rustup and the stable Rust toolchain"
)

cargo_install() {
  command -v "$1" >/dev/null 2>&1 && { ok "$1 already installed; skipping"; return 0; }
  if dryrun; then would "cargo install $1"; return 0; fi
  command -v cargo >/dev/null || { record_failure "$1" 'cargo is unavailable'; return 0; }
  cargo install "$1" || record_failure "$1" 'cargo installation failed'
}
