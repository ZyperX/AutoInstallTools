#!/usr/bin/env bats
# Platform helpers: distro detection, the macOS catalog filter, Homebrew
# installs, Kali package preference, and VPS tuning. No network or root.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT BOOTSTRAP_HOME="$BATS_TEST_TMPDIR/ait" HOME="$BATS_TEST_TMPDIR/h"
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
}

# Write an os-release fixture and print its path.
os_release() { # <file> <id> <like> <pretty>
  local file=$BATS_TEST_TMPDIR/os/$1
  mkdir -p "$BATS_TEST_TMPDIR/os"
  printf 'ID=%s\nID_LIKE="%s"\nPRETTY_NAME="%s"\n' "$2" "$3" "$4" > "$file"
  printf '%s' "$file"
}

@test "distro detection matches ID and ID_LIKE" {
  local ubuntu debian kali
  ubuntu=$(os_release ubuntu ubuntu debian 'Ubuntu 24.04 LTS')
  debian=$(os_release debian debian '' 'Debian GNU/Linux 12 (bookworm)')
  kali=$(os_release kali kali debian 'Kali GNU/Linux Rolling')

  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/platform.sh"
    AIT_OS_RELEASE="'"$ubuntu"'" distro_name | grep -q "Ubuntu 24.04"
    AIT_OS_RELEASE="'"$ubuntu"'" is_ubuntu && AIT_OS_RELEASE="'"$ubuntu"'" is_debian || exit 1
    AIT_OS_RELEASE="'"$debian"'" is_debian || exit 1
    AIT_OS_RELEASE="'"$debian"'" is_ubuntu && exit 1
    AIT_OS_RELEASE="'"$kali"'" is_kali && AIT_OS_RELEASE="'"$kali"'" is_debian || exit 1
    AIT_OS_RELEASE="'"$kali"'" is_ubuntu && exit 1
    exit 0'
  [ "$status" -eq 0 ]
}

@test "macOS resolver keeps Homebrew/portable tools and skips Linux-only releases" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/platform.sh"
    source "$ROOT/lib/catalog.sh"; bootstrap_yq >/dev/null
    AIT_PLATFORM=macos
    export AIT_PLATFORM
    names=$(resolve_tools web "" "")
    grep -qx nmap <<<"$names" || { echo "nmap (brew) missing"; exit 1; }
    grep -qx subfinder <<<"$names" || { echo "subfinder (go) missing"; exit 1; }
    ! grep -qx x8 <<<"$names" || { echo "x8 has no darwin asset"; exit 1; }
    ! grep -qx tlsx <<<"$names" || { echo "tlsx has no darwin asset"; exit 1; }
    out=$(resolve_tools web "tlsx" "" 2>&1)
    grep -q "tlsx is not available on macos" <<<"$out" || { echo "no skip warning: $out"; exit 1; }
    ! grep -qx tlsx <<<"$out" || { echo "explicit tlsx was selected"; exit 1; }
    exit 0'
  [ "$status" -eq 0 ]
}

@test "catalog_tool_bin prefers brew_bin only on macOS" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/platform.sh"
    source "$ROOT/lib/catalog.sh"; bootstrap_yq >/dev/null
    [ "$(AIT_PLATFORM=macos catalog_tool_bin fd)" = fd ] || exit 1
    [ "$(AIT_PLATFORM=macos catalog_tool_bin bat)" = bat ] || exit 1
    [ "$(AIT_PLATFORM=macos catalog_tool_bin whiptail)" = whiptail ] || exit 1
    [ "$(AIT_PLATFORM=linux catalog_tool_bin fd)" = fdfind ] || exit 1
    [ "$(AIT_PLATFORM=linux catalog_tool_bin bat)" = batcat ] || exit 1
    exit 0'
  [ "$status" -eq 0 ]
}

@test "Kali apt is preferred only when the package is at least the pin" {
  local kali ubuntu fakebin=$BATS_TEST_TMPDIR/bin
  kali=$(os_release kali kali debian 'Kali GNU/Linux Rolling')
  ubuntu=$(os_release ubuntu ubuntu debian 'Ubuntu 24.04 LTS')

  cat > "$fakebin/apt-cache" <<'EOF'
#!/usr/bin/env bash
# apt-cache policy <pkg> -> a canonical version per package
pkg=${!#}
case "$pkg" in
  feroxbuster) echo "  Candidate: ${FAKE_FEROX:-2.13.1-0kali1}" ;;
  amass)       echo "  Candidate: ${FAKE_AMASS:-5.1.3-0kali1}" ;;
  *)           echo "  Candidate: 1.0.0" ;;
esac
EOF
  chmod +x "$fakebin/apt-cache"

  run bash -c '
    export PATH="'"$fakebin"':$PATH"
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/platform.sh"
    source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/dispatch.sh"
    bootstrap_yq >/dev/null
    AIT_OS_RELEASE="'"$kali"'" _kali_apt_current feroxbuster || exit 1
    [ "${KALI_APT_PKGS[*]}" = feroxbuster ] || exit 1
    AIT_OS_RELEASE="'"$kali"'" _kali_apt_current amass || exit 1
    AIT_OS_RELEASE="'"$kali"'" FAKE_FEROX=2.0.0 _kali_apt_current feroxbuster && exit 1
    AIT_OS_RELEASE="'"$kali"'" _kali_apt_current subfinder && exit 1
    AIT_OS_RELEASE="'"$ubuntu"'" _kali_apt_current feroxbuster && exit 1
    exit 0'
  [ "$status" -eq 0 ]
}

@test "brew install is idempotent and dry-run changes nothing" {
  local fakebin=$BATS_TEST_TMPDIR/bin
  cat > "$fakebin/brew" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == list ]] && exit "${FAKE_BREW_INSTALLED:-1}"
exit 0
EOF
  chmod +x "$fakebin/brew"

  run bash -c '
    export PATH="'"$fakebin"':$PATH"
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/homebrew.sh"
    out=$(FAKE_BREW_INSTALLED=0 brew_install_formulas demo 2>&1)
    grep -q "demo already installed" <<<"$out" || exit 1
    ! grep -q "brew install demo" <<<"$out" || exit 1
    DRY_RUN=1 out=$(brew_install_formulas demo 2>&1)
    grep -q "would brew install demo" <<<"$out" || exit 1
    exit 0'
  [ "$status" -eq 0 ]
}

@test "VPS tuning is idempotent, reversible and honours dry-run" {
  local fakebin=$BATS_TEST_TMPDIR/bin
  # Never touch /etc in tests: a fake sudo that always fails makes the
  # system-wide limits step a warning instead of a write.
  printf '#!/usr/bin/env bash\nexit 1\n' > "$fakebin/sudo"
  chmod +x "$fakebin/sudo"

  run bash -c '
    export PATH="'"$fakebin"':$PATH" SHELL=/bin/bash
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/tuning.sh"
    DRY_RUN=1 vps_tune >/dev/null 2>&1
    [ ! -e "$HOME/.tmux.conf" ] && [ ! -e "$BOOTSTRAP_HOME/tmux.conf" ] || exit 1
    vps_tune >/dev/null 2>&1
    vps_tune >/dev/null 2>&1
    [ "$(grep -c "# >>> AIT limits >>>" "$HOME/.bashrc")" -eq 1 ] || exit 1
    [ "$(grep -c "# >>> AIT tmux >>>" "$HOME/.tmux.conf")" -eq 1 ] || exit 1
    [ -f "$BOOTSTRAP_HOME/tmux.conf" ] || exit 1
    vps_untune
    ! grep -q "AIT limits" "$HOME/.bashrc" || exit 1
    ! grep -q "AIT tmux" "$HOME/.tmux.conf" || exit 1
    [ ! -e "$BOOTSTRAP_HOME/tmux.conf" ] || exit 1
    exit 0'
  [ "$status" -eq 0 ]
}
