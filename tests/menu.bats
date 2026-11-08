#!/usr/bin/env bats
# Interactive menu: text fallback and menu → profile mapping (no TTY needed).

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT HOME="$BATS_TEST_TMPDIR/h" BIN_DIR="$BATS_TEST_TMPDIR/bin"
  # Share one yq bootstrap across the suite so tests don't re-download it.
  export BOOTSTRAP_HOME="$BATS_SUITE_TMPDIR/ait" AIT_MENU_TEXT=1
  mkdir -p "$HOME" "$BIN_DIR"
}

@test "text checklist accepts ranges and comma lists" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    rows=$(printf "android\tjadx\tON\t[android] jadx\nweb\tffuf\tON\t[web] ffuf\nios\tipatool\tON\t[ios] ipatool")
    printf "1,3\n" | _menu_checklist_text Pick "$rows"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"jadx ipatool"* ]]
}

@test "text checklist expands ranges and a=all" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    rows=$(printf "android\tjadx\tON\t[android] jadx\nweb\tffuf\tON\t[web] ffuf\nios\tipatool\tON\t[ios] ipatool")
    printf "1-2\n" | _menu_checklist_text Pick "$rows"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"jadx ffuf"* ]]

  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    rows=$(printf "android\tjadx\tON\t[android] jadx\nweb\tffuf\tON\t[web] ffuf")
    printf "a\n" | _menu_checklist_text Pick "$rows"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"jadx ffuf"* ]]
}

@test "mobile rows show descriptions and keep opt-in tools unticked" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    bootstrap_yq >/dev/null
    _menu_rows mobile'
  [ "$status" -eq 0 ]
  [[ "$output" == *"jadx"* ]]
  [[ "$output" == *"DEX to Java decompiler"* ]]
  [[ "$output" == *"objection"* ]]
  [[ "$output" != *"subfinder"* ]]
  # medusa is opt_in: its row must start unticked.
  medusa_row=$(grep -F $'\tmedusa\t' <<<"$output")
  [[ "$medusa_row" == *$'\tOFF\t'* ]]
}

@test "menu entry 4 maps to the mobile profile" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    bootstrap_yq >/dev/null
    _menu_profile() { printf "PROFILE=%s\n" "$1"; }
    printf "4\n" | menu_main'
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROFILE=mobile"* ]]
}

@test "menu entry 2 maps to the web profile" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    bootstrap_yq >/dev/null
    _menu_profile() { printf "PROFILE=%s\n" "$1"; }
    printf "2\n" | menu_main'
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROFILE=web"* ]]
}

@test "menu entry 3 maps to the api profile" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    bootstrap_yq >/dev/null
    _menu_profile() { printf "PROFILE=%s\n" "$1"; }
    printf "3\n" | menu_main'
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROFILE=api"* ]]
}

@test "menu entry 5 maps to the code profile" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    bootstrap_yq >/dev/null
    _menu_profile() { printf "PROFILE=%s\n" "$1"; }
    printf "5\n" | menu_main'
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROFILE=code"* ]]
}

@test "menu entry 6 maps to the vps profile" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    bootstrap_yq >/dev/null
    _menu_profile() { printf "PROFILE=%s\n" "$1"; }
    printf "6\n" | menu_main'
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROFILE=vps"* ]]
}

@test "menu entry 7 maps to the ai profile" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    bootstrap_yq >/dev/null
    _menu_profile() { printf "PROFILE=%s\n" "$1"; }
    printf "7\n" | menu_main'
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROFILE=ai"* ]]
}

@test "menu entry 8 installs the all profile" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    bootstrap_yq >/dev/null
    _menu_yesno() { return 0; }
    ait_install() { printf "AIT_INSTALL %s\n" "$*"; }
    printf "8\n" | menu_main'
  [ "$status" -eq 0 ]
  [[ "$output" == *"AIT_INSTALL --profile all --yes"* ]]
}

@test "select tools calls the shared installer with the profile label" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/menu.sh"
    bootstrap_yq >/dev/null
    ait_install_names() { printf "INSTALL label=%s names=%s\n" "$1" "$*"; }
    printf "1\ny\n" | _menu_select mobile "Mobile"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"INSTALL label=mobile"* ]]
}
