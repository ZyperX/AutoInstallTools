#!/usr/bin/env bash
# Distro/platform helpers: what we are running on, and what that allows.
# Linux/WSL is primary; Debian 12 and Kali are supported; macOS is a beta that
# uses Homebrew for system packages.

# AIT_OS_RELEASE points at a fixture in tests (default /etc/os-release).
os_release_file() { printf '%s\n' "${AIT_OS_RELEASE:-/etc/os-release}"; }

# distro_field <KEY> -> value from os-release, quotes stripped.
distro_field() {
  local key=$1 file; file=$(os_release_file)
  [[ -f "$file" ]] || return 0
  awk -F= -v k="$key" '$1 == k { v = substr($0, index($0, "=") + 1); gsub(/^"|"$/, "", v); print v; exit }' "$file"
}

distro_id()   { distro_field ID; }
distro_like() { distro_field ID_LIKE; }
distro_name() {
  local n; n=$(distro_field PRETTY_NAME)
  if [[ -n "$n" ]]; then printf '%s\n' "$n"; else uname -s; fi
}

# distro_is <id>: matches ID or any ID_LIKE entry (kali→debian, ubuntu→debian).
distro_is() {
  local want=$1 id like w
  id=$(distro_id); like=$(distro_like)
  [[ "$id" == "$want" ]] && return 0
  for w in $like; do [[ "$w" == "$want" ]] && return 0; done
  return 1
}
is_kali()   { distro_is kali; }
is_debian() { distro_is debian; }
is_ubuntu() { distro_is ubuntu; }

# One-line summary for `ait doctor` and failure reports.
platform_line() {
  local p; p=$(detect_platform)
  case "$p" in
    wsl) printf 'WSL2 (%s)' "$(distro_name)" ;;
    linux) printf 'Linux (%s)' "$(distro_name)" ;;
    macos) printf 'macOS %s' "$(sw_vers -productVersion 2>/dev/null || echo '')" ;;
    *) printf '%s' "$p" ;;
  esac
}

# require_supported: OS + package-manager prerequisites for `ait install`.
require_supported() {
  case "$(uname -s)" in
    Linux)
      command -v sudo >/dev/null 2>&1 || die 'sudo is required to install system packages.'
      ;;
    Darwin)
      ;;
    *)
      die "Unsupported platform: $(uname -s). Linux, WSL2 and macOS (beta) are supported."
      ;;
  esac
}

# require_brew: macOS installs system packages with Homebrew. Never pipe a
# remote script into a shell.
require_brew() {
  command -v brew >/dev/null 2>&1 && return 0
  die 'Homebrew is required on macOS. Install it from https://brew.sh, then re-run.'
}

# apt_candidate_version <package>: the version apt would install (empty if none).
apt_candidate_version() {
  command -v apt-cache >/dev/null 2>&1 || return 1
  apt-cache policy "$1" 2>/dev/null | awk '/^[[:space:]]*Candidate:/ { print $2; exit }'
}

# _kali_apt_current <tool>: on Kali, sets KALI_APT_PKGS when the catalog's
# `kali_apt` package is at least the pinned `version`. A stale Kali package
# must never replace the pinned upstream release.
_kali_apt_current() {
  local name=$1 version cand pkg
  KALI_APT_PKGS=()
  is_kali || return 1
  mapfile -t KALI_APT_PKGS < <(catalog_tool_list "$name" kali_apt)
  ((${#KALI_APT_PKGS[@]})) || return 1
  version=$(catalog_tool_field "$name" version); version=${version#v}
  [[ -n "$version" ]] || return 1
  for pkg in "${KALI_APT_PKGS[@]}"; do
    cand=$(apt_candidate_version "$pkg")
    [[ -n "$cand" ]] || return 1
    if command -v dpkg >/dev/null 2>&1; then
      dpkg --compare-versions "$cand" ge "$version" || return 1
    fi
  done
  return 0
}
