#!/usr/bin/env bats
# Apt method behavior with package-manager commands stubbed out.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT HOME="$BATS_TEST_TMPDIR/home" BIN_DIR="$BATS_TEST_TMPDIR/bin"
  export MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin" MOCK_LOG="$BATS_TEST_TMPDIR/apt.log"
  mkdir -p "$HOME" "$BIN_DIR" "$MOCK_BIN"
  cat > "$MOCK_BIN/dpkg-query" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  cat > "$MOCK_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LOG"
EOF
  chmod +x "$MOCK_BIN/dpkg-query" "$MOCK_BIN/sudo"
  export PATH="$MOCK_BIN:$PATH"
}

@test "apt index is refreshed once and package batches are installed" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/apt.sh"
    export FAILURES_FILE="$BATS_TEST_TMPDIR/failures"; : > "$FAILURES_FILE"
    apt_install alpha beta
    apt_install gamma
    [[ $(grep -c "apt-get update" "$MOCK_LOG") == 1 ]]
    grep -Fq "apt-get install -y --no-install-recommends alpha beta" "$MOCK_LOG"
    grep -Fq "apt-get install -y --no-install-recommends gamma" "$MOCK_LOG"'
  [ "$status" -eq 0 ]
}

@test "apt failure is retried package by package and recorded" {
  cat > "$MOCK_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LOG"
case " $* " in *' badpkg '*) exit 1 ;; esac
EOF
  chmod +x "$MOCK_BIN/sudo"
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/apt.sh"
    export FAILURES_FILE="$BATS_TEST_TMPDIR/failures"; : > "$FAILURES_FILE"
    export APT_UPDATED_RUN=1
    apt_install goodpkg badpkg
    grep -Fxq badpkg "$FAILURES_FILE"
    grep -Fq "apt-get install -y --no-install-recommends goodpkg" "$MOCK_LOG"'
  [ "$status" -eq 0 ]
}

@test "failure summary returns nonzero after recording failures" {
  run bash -c '
    source "$ROOT/lib/common.sh"
    export STATE_DIR="$BATS_TEST_TMPDIR/state"
    begin_failure_report
    record_failure example "mock failure"
    report_failures'
  [ "$status" -ne 0 ]
}
