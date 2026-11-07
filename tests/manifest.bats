#!/usr/bin/env bats
# Manifest: install row is written, queried, and removed.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT BOOTSTRAP_HOME="$BATS_TEST_TMPDIR/ait" STATE_DIR="$BATS_TEST_TMPDIR/ait/state" HOME="$BATS_TEST_TMPDIR/h"
  mkdir -p "$HOME"
}

@test "manifest add -> query -> remove round trip" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/manifest.sh"
    manifest_init
    manifest_add demo github_release v1.2.3 /tmp/demo
    manifest_has demo || exit 1
    [ "$(manifest_field demo 2)" = github_release ] || exit 1
    [ "$(manifest_field demo 3)" = v1.2.3 ] || exit 1
    manifest_remove_row demo
    manifest_has demo && exit 1
    exit 0'
  [ "$status" -eq 0 ]
}

@test "ait uninstall --tools removes the file and the row" {
  run bash -c '
    export BIN_DIR="$BATS_TEST_TMPDIR/h/.local/bin" WORDLISTS="$BATS_TEST_TMPDIR/h/WL" CI=true
    mkdir -p "$BIN_DIR"
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/manifest.sh"
    manifest_init
    touch "$BIN_DIR/demo"
    manifest_add demo github_release v1 "$BIN_DIR/demo"
    "$ROOT/ait" uninstall --tools demo --yes >/dev/null 2>&1
    [ ! -e "$BIN_DIR/demo" ] || exit 1
    source "$ROOT/lib/manifest.sh"; manifest_has demo && exit 1
    exit 0'
  [ "$status" -eq 0 ]
}
