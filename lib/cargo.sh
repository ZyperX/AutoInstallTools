#!/usr/bin/env bash
cargo_install(){
  command -v "$1" >/dev/null 2>&1 && { ok "$1 already installed; skipping"; return 0; }
  command -v cargo >/dev/null || { record_failure "$1" 'cargo is unavailable'; return 0; }
  cargo install "$1" || record_failure "$1" 'cargo installation failed'
}
