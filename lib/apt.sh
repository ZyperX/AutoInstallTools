#!/usr/bin/env bash
# apt install method. Records per-package failures and continues.

apt_install() {
  local package missing=()
  for package in "$@"; do
    if dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
      ok "$package already installed; skipping"
    else
      missing+=("$package")
    fi
  done
  ((${#missing[@]})) || return 0

  if dryrun; then
    would "apt-get install ${missing[*]}"
    return 0
  fi

  if [[ ${APT_UPDATED_RUN:-0} != 1 ]]; then
    if ! sudo apt-get update -y; then
      record_failure 'apt package index' 'apt-get update failed'
      return 0
    fi
    APT_UPDATED_RUN=1
  fi

  if sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"; then
    return 0
  fi

  # Retry individually so an unavailable package does not block the rest.
  for package in "${missing[@]}"; do
    if ! dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
      if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$package"; then
        record_failure "$package" 'apt installation failed'
      fi
    fi
  done
}

apt_update_all() {
  run sudo apt-get update -y
  run sudo apt-get upgrade -y
  run sudo apt-get autoremove -y
}
