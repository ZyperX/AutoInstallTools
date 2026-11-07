#!/usr/bin/env bats
# Catalog schema + profile resolver (delegates to the standalone test scripts).

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT BOOTSTRAP_HOME="$BATS_TEST_TMPDIR/ait" HOME="$BATS_TEST_TMPDIR/h"
  mkdir -p "$HOME"
}

@test "catalog validates against the schema" {
  run bash "$ROOT/tests/validate-catalog.sh"
  [ "$status" -eq 0 ]
}

@test "profile resolver behaves as specified" {
  run bash "$ROOT/tests/resolver.sh"
  [ "$status" -eq 0 ]
}
