#!/usr/bin/env bats
# Release-asset extraction: versioned binaries (dots in the name) are still found.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT HOME="$BATS_TEST_TMPDIR/h" BIN_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$HOME" "$BIN_DIR"
}

@test "gh_install_from_file finds a versioned binary inside a tarball" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/github.sh"
    src=$(mktemp -d); mkdir -p "$src/bin"
    printf "#!/bin/sh\necho ok\n" > "$src/bin/ipatool-2.7.0-linux-amd64"
    chmod +x "$src/bin/ipatool-2.7.0-linux-amd64"
    tar -czf "$src/a.tar.gz" -C "$src" bin
    gh_install_from_file "$src/a.tar.gz" a.tar.gz ipatool "$BIN_DIR/ipatool"
    test -x "$BIN_DIR/ipatool"'
  [ "$status" -eq 0 ]
}

@test "gh_install_from_file falls back to any executable" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/github.sh"
    src=$(mktemp -d)
    printf "#!/bin/sh\necho ok\n" > "$src/renamed-tool"
    chmod +x "$src/renamed-tool"
    tar -czf "$src/a.tar.gz" -C "$src" renamed-tool
    gh_install_from_file "$src/a.tar.gz" a.tar.gz expected "$BIN_DIR/tool"
    test -x "$BIN_DIR/tool"'
  [ "$status" -eq 0 ]
}

@test "release verifier rejects a release with no published SHA-256" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/github.sh"
    export FAILURES_FILE="$BATS_TEST_TMPDIR/failures"; : > "$FAILURES_FILE"
    file=$(mktemp); printf payload > "$file"
    json="{\"assets\":[{\"name\":\"tool.tar.gz\",\"browser_download_url\":\"https://example.invalid/tool.tar.gz\"}]}"
    if _gh_verify_checksum "$json" tool.tar.gz "$file" tool; then exit 1; fi
    grep -Fxq tool "$FAILURES_FILE"'
  [ "$status" -eq 0 ]
}

@test "release verifier checks GitHub asset digest" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/github.sh"
    export FAILURES_FILE="$BATS_TEST_TMPDIR/failures"; : > "$FAILURES_FILE"
    file=$(mktemp); printf payload > "$file"
    digest=$(sha256_of "$file")
    json="{\"assets\":[{\"name\":\"tool\",\"digest\":\"sha256:$digest\"}]}"
    _gh_verify_checksum "$json" tool "$file" tool'
  [ "$status" -eq 0 ]
}
