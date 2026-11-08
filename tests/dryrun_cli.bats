#!/usr/bin/env bats
# The catalog CLI must not create managed state during preview operations.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT HOME="$BATS_TEST_TMPDIR/home" BIN_DIR="$BATS_TEST_TMPDIR/bin"
  export BOOTSTRAP_HOME="$BATS_TEST_TMPDIR/ait" WORDLISTS="$BATS_TEST_TMPDIR/wordlists"
  mkdir -p "$HOME" "$BIN_DIR"
}

@test "install dry-run leaves the home directory untouched" {
  run "$ROOT/ait" install --profile minimal --dry-run --yes --no-shell
  [ "$status" -eq 0 ]
  [ ! -e "$BOOTSTRAP_HOME" ]
  [ ! -e "$BIN_DIR/go" ]
  [ ! -e "$WORDLISTS" ]
}

@test "update dry-run leaves managed state untouched" {
  run "$ROOT/ait" update --tools jq --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$BOOTSTRAP_HOME" ]
  [ ! -e "$BIN_DIR/jq" ]
}

@test "uninstall dry-run preserves payload and manifest" {
  mkdir -p "$BOOTSTRAP_HOME/state" "$HOME/managed"
  printf 'sample\tgit\t-\t%s\t2026-01-01T00:00:00Z\n' "$HOME/managed/payload" \
    > "$BOOTSTRAP_HOME/state/manifest.tsv"
  printf 'keep\n' > "$HOME/managed/payload"
  cp "$BOOTSTRAP_HOME/state/manifest.tsv" "$BATS_TEST_TMPDIR/manifest.before"

  run "$ROOT/ait" uninstall --tools sample --dry-run --yes
  [ "$status" -eq 0 ]
  [ -f "$HOME/managed/payload" ]
  cmp -s "$BOOTSTRAP_HOME/state/manifest.tsv" "$BATS_TEST_TMPDIR/manifest.before"
}
