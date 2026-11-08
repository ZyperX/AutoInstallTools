#!/usr/bin/env bash
# Homebrew install method (macOS beta). Requires Homebrew; never bootstraps it
# with a curl|bash one-liner. Formulas and casks are checked before installing
# and recorded in the manifest for `ait uninstall`.

brew_available() { command -v brew >/dev/null 2>&1; }

_brew_installed() { # <formula|cask> <name>
  local kind=$1 name=$2
  brew list "$kind" -- "$name" >/dev/null 2>&1
}

# brew_install_formulas <formula...>
brew_install_formulas() {
  (($#)) || return 0
  if ! brew_available; then
    local f; for f in "$@"; do record_failure "$f" 'Homebrew is not installed'; done
    return 0
  fi
  local f missing=()
  for f in "$@"; do
    if _brew_installed --formula "$f"; then ok "$f already installed; skipping"; else missing+=("$f"); fi
  done
  ((${#missing[@]})) || return 0
  if dryrun; then would "brew install ${missing[*]}"; return 0; fi
  brew install "${missing[@]}" || { record_failure "${missing[*]}" 'brew install failed'; return 0; }
  ok "brew: ${missing[*]}"
}

# brew_install_casks <cask...>
brew_install_casks() {
  (($#)) || return 0
  if ! brew_available; then
    local c; for c in "$@"; do record_failure "$c" 'Homebrew is not installed'; done
    return 0
  fi
  local c missing=()
  for c in "$@"; do
    if _brew_installed --cask "$c"; then ok "$c already installed; skipping"; else missing+=("$c"); fi
  done
  ((${#missing[@]})) || return 0
  if dryrun; then would "brew install --cask ${missing[*]}"; return 0; fi
  brew install --cask "${missing[@]}" || { record_failure "${missing[*]}" 'brew cask install failed'; return 0; }
  ok "brew cask: ${missing[*]}"
}

# Remove a formula/cask on uninstall (manifest prefix brew:/cask:).
brew_uninstall() { # <formula|cask> <name>
  local kind=$1 name=$2
  brew_available || return 0
  _brew_installed "$kind" "$name" || return 0
  if [[ "$kind" == --cask ]]; then brew uninstall --cask "$name" || true
  else brew uninstall "$name" || true; fi
}
