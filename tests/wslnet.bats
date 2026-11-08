#!/usr/bin/env bats
# .wslconfig editing: missing file, no [wsl2], existing key, other keys, CRLF.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT HOME="$BATS_TEST_TMPDIR/h" BIN_DIR="$BATS_TEST_TMPDIR/bin"
  export BOOTSTRAP_HOME="$BATS_TEST_TMPDIR/ait"
  export WSL_CONFIG="$BATS_TEST_TMPDIR/.wslconfig"
  mkdir -p "$HOME" "$BIN_DIR"
}

_run() { # evaluate a snippet with the shared helpers sourced
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/wslnet.sh"
    '"$1"
}

@test "creates .wslconfig with [wsl2] and a CRLF key when missing" {
  _run 'wsl_net_set mirrored'
  [ "$status" -eq 0 ]
  [ -f "$WSL_CONFIG" ]
  grep -q '^\[wsl2\]' "$WSL_CONFIG"
  grep -q '^networkingMode=mirrored' "$WSL_CONFIG"
  # CRLF-safe: every line ends with \r.
  [ "$(grep -c $'\r$' "$WSL_CONFIG")" -eq "$(wc -l < "$WSL_CONFIG")" ]
}

@test "adds [wsl2] without touching other sections" {
  printf '[experimental]\nautoMemoryReclaim=gradual\n' > "$WSL_CONFIG"
  _run 'wsl_net_set nat'
  [ "$status" -eq 0 ]
  grep -qxF 'autoMemoryReclaim=gradual' "$WSL_CONFIG"
  grep -q '^\[wsl2\]$' "$WSL_CONFIG"
  grep -qxF 'networkingMode=nat' "$WSL_CONFIG"
}

@test "replaces only networkingMode and keeps the other keys" {
  printf '[wsl2]\nmemory=8GB\nnetworkingMode=nat\nlocalhostForwarding=true\n' > "$WSL_CONFIG"
  _run 'wsl_net_set mirrored'
  [ "$status" -eq 0 ]
  [ "$(grep -c '^networkingMode=' "$WSL_CONFIG")" -eq 1 ]
  grep -qxF 'networkingMode=mirrored' "$WSL_CONFIG"
  grep -qxF 'memory=8GB' "$WSL_CONFIG"
  grep -qxF 'localhostForwarding=true' "$WSL_CONFIG"
}

@test "adds the key to an existing [wsl2] section and backs up first" {
  printf '[wsl2]\nmemory=4GB\n' > "$WSL_CONFIG"
  _run 'wsl_net_set mirrored'
  [ "$status" -eq 0 ]
  grep -qxF 'networkingMode=mirrored' "$WSL_CONFIG"
  grep -qxF 'memory=4GB' "$WSL_CONFIG"
  local backups; backups=$(find "$BATS_TEST_TMPDIR" -maxdepth 1 -name '.wslconfig.ait-backup-*' | wc -l)
  [ "$backups" -ge 1 ]
}

@test "preserves CRLF line endings" {
  printf '[wsl2]\r\nmemory=4GB\r\n' > "$WSL_CONFIG"
  _run 'wsl_net_set mirrored'
  [ "$status" -eq 0 ]
  [ "$(grep -c $'\r$' "$WSL_CONFIG")" -eq "$(wc -l < "$WSL_CONFIG")" ]
  grep -q 'networkingMode=mirrored' "$WSL_CONFIG"
}

@test "dry-run prints a diff and changes nothing" {
  printf '[wsl2]\nnetworkingMode=nat\n' > "$WSL_CONFIG"
  before=$(cat "$WSL_CONFIG")
  _run 'DRY_RUN=1; wsl_net_set mirrored'
  [ "$status" -eq 0 ]
  [[ "$output" == *'networkingMode=mirrored'* ]]
  [ "$(cat "$WSL_CONFIG")" = "$before" ]
}

@test "toggle flips between nat and mirrored" {
  printf '[wsl2]\nnetworkingMode=nat\n' > "$WSL_CONFIG"
  _run 'wsl_net_toggle'
  [ "$status" -eq 0 ]
  grep -qxF 'networkingMode=mirrored' "$WSL_CONFIG"
  _run 'wsl_net_toggle'
  [ "$status" -eq 0 ]
  grep -qxF 'networkingMode=nat' "$WSL_CONFIG"
}

@test "status reports restart pending when live differs from configured" {
  printf '[wsl2]\nnetworkingMode=mirrored\n' > "$WSL_CONFIG"
  _run 'AIT_WSL_LIVE_MODE=nat wsl_net_status'
  [ "$status" -eq 0 ]
  [[ "$output" == *'Configured: mirrored'* ]]
  [[ "$output" == *'Live:       nat'* ]]
  [[ "$output" == *'restart pending'* ]]
}

@test "mirrored mode refuses Windows builds below 22621 without editing config" {
  printf '[wsl2]\nnetworkingMode=nat\n' > "$WSL_CONFIG"
  before=$(cat "$WSL_CONFIG")
  _run 'AIT_WSL2=1 AIT_WSL_BUILD=22620 wsl_net_cli mirrored'
  [ "$status" -ne 0 ]
  [[ "$output" == *'too old for mirrored networking'* ]]
  [ "$(cat "$WSL_CONFIG")" = "$before" ]
}

@test "mirrored mode accepts Windows build 22621 and dry-run preserves config" {
  printf '[wsl2]\nnetworkingMode=nat\n' > "$WSL_CONFIG"
  _run 'AIT_WSL2=1 AIT_WSL_BUILD=22621 wsl_net_cli mirrored --dry-run'
  [ "$status" -eq 0 ]
  [[ "$output" == *'networkingMode=mirrored'* ]]
  grep -qxF 'networkingMode=nat' "$WSL_CONFIG"
}
