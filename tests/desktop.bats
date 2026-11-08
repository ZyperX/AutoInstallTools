#!/usr/bin/env bats
# WSL .desktop launchers: created for installed GUI tools and removed again.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT HOME="$BATS_TEST_TMPDIR/h" BIN_DIR="$BATS_TEST_TMPDIR/bin"
  export BOOTSTRAP_HOME="$BATS_SUITE_TMPDIR/ait" AIT_WSL=1
  export AIT_DESKTOP_DIR="$BATS_TEST_TMPDIR/applications"
  mkdir -p "$HOME" "$BIN_DIR"
}

@test "writes a launcher for an installed GUI tool" {
  printf '#!/bin/sh\nexit 0\n' > "$BIN_DIR/caido-desktop"
  chmod +x "$BIN_DIR/caido-desktop"
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/desktop.sh"
    bootstrap_yq >/dev/null
    desktop_launchers_refresh'
  [ "$status" -eq 0 ]
  [ -f "$AIT_DESKTOP_DIR/ait-caido-desktop.desktop" ]
  grep -qxF 'Type=Application' "$AIT_DESKTOP_DIR/ait-caido-desktop.desktop"
  grep -qF "Exec=\"$BIN_DIR/caido-desktop\"" "$AIT_DESKTOP_DIR/ait-caido-desktop.desktop"
}

@test "skips GUI tools that are not installed" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/catalog.sh"; source "$ROOT/lib/desktop.sh"
    bootstrap_yq >/dev/null
    desktop_launchers_refresh'
  [ "$status" -eq 0 ]
  [ ! -e "$AIT_DESKTOP_DIR/ait-jadx-gui.desktop" ]
}

@test "removes a launcher on uninstall" {
  mkdir -p "$AIT_DESKTOP_DIR"
  printf '[Desktop Entry]\n' > "$AIT_DESKTOP_DIR/ait-jadx-gui.desktop"
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/desktop.sh"
    desktop_launcher_remove jadx-gui'
  [ "$status" -eq 0 ]
  [ ! -e "$AIT_DESKTOP_DIR/ait-jadx-gui.desktop" ]
}
