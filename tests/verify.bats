#!/usr/bin/env bats
# sha256 verification: a good file passes, a tampered file is rejected.

setup() { ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"; export ROOT; }

@test "verify_sha256 accepts a matching file" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/verify.sh"
    f=$(mktemp); printf payload > "$f"
    s=$(sha256sum "$f" | cut -d" " -f1)
    verify_sha256 "$f" "$s"'
  [ "$status" -eq 0 ]
}

@test "verify_sha256 rejects a tampered file" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/verify.sh"
    f=$(mktemp); printf payload > "$f"
    s=$(sha256sum "$f" | cut -d" " -f1)
    printf tampered >> "$f"
    verify_sha256 "$f" "$s"'
  [ "$status" -ne 0 ]
}

@test "checksum_from_file extracts the right hash" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/verify.sh"
    cf=$(mktemp); printf "%s  tool_linux_amd64.tar.gz\n" deadbeef > "$cf"
    [ "$(checksum_from_file "$cf" tool_linux_amd64.tar.gz)" = deadbeef ]'
  [ "$status" -eq 0 ]
}
