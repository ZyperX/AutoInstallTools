#!/usr/bin/env bash
apt_install(){
  local package missing=()
  for package in "$@"; do
    if dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
      ok "$package already installed; skipping"
    else
      missing+=("$package")
    fi
  done
  ((${#missing[@]})) || return 0
  if ! sudo apt-get update -y; then
    record_failure 'apt package index' 'apt-get update failed'
    return 0
  fi
  for package in "${missing[@]}"; do
    if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$package"; then
      record_failure "$package" 'apt installation failed'
    fi
  done
}
apt_update_all(){ sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get autoremove -y; }
