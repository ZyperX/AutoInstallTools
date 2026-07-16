#!/usr/bin/env bash
# NodeSource supplies an actively supported Node.js LTS release; Ubuntu's default
# repository can be several major versions behind.
node_major() { node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'; }

install_node_lts() (
  local major setup
  major="$(node_major || true)"
  if [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 22 )); then
    ok "Node.js v$(node --version) already meets the >=22 requirement"
    return 0
  fi

  command -v curl >/dev/null || { record_failure 'nodejs' 'curl is unavailable'; return 0; }
  setup="$(mktemp)"
  trap 'rm -f -- "$setup"' EXIT
  retry curl -fsSL -o "$setup" https://deb.nodesource.com/setup_22.x || { record_failure 'nodejs' 'could not download NodeSource setup'; return 0; }
  sudo -E bash "$setup" || { record_failure 'nodejs' 'could not add the NodeSource repository'; return 0; }
  rm -f -- "$setup"
  apt_install nodejs
  major="$(node_major || true)"
  [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 22 )) || { record_failure 'nodejs' 'Node.js >=22 was not installed successfully'; return 0; }
  ok "Installed Node.js $(node --version)"
)
