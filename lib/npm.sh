#!/usr/bin/env bash
# npm global install method, kept inside the user's home.

npm_configure_user_prefix() {
  command -v npm >/dev/null || return 0
  # Never write global packages into /usr/local: it causes EACCES and encourages sudo npm.
  npm config set prefix "$HOME/.local"
  mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
}

npm_install() {
  local package
  if dryrun; then
    for package in "$@"; do would "npm install -g $package"; done
    return 0
  fi
  command -v npm >/dev/null || { record_failure "$1" 'npm is unavailable'; return 0; }
  npm_configure_user_prefix
  for package in "$@"; do
    if npm list -g --depth=0 "$package" >/dev/null 2>&1; then
      ok "$package already installed; skipping"
    else
      npm install -g "$package" || record_failure "$package" 'npm installation failed'
    fi
  done
}
