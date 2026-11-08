#!/usr/bin/env bats
# Mobile helpers: ABI mapping, proxy CA naming and the frida-server dry run.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ROOT HOME="$BATS_TEST_TMPDIR/h" BIN_DIR="$BATS_TEST_TMPDIR/bin"
  export BOOTSTRAP_HOME="$BATS_TEST_TMPDIR/ait"
  mkdir -p "$HOME" "$BIN_DIR" "$BATS_TEST_TMPDIR/certs"
}

_make_cert() { # <out> <format>
  local out=$1 fmt=${2:-PEM}
  if [[ "$fmt" == DER ]]; then
    openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=ait-test-ca' \
      -keyout "$out.key" -out "$out.pem" >/dev/null 2>&1
    openssl x509 -in "$out.pem" -outform DER -out "$out" >/dev/null 2>&1
    rm -f "$out.key" "$out.pem"
  else
    openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=ait-test-ca' \
      -keyout "$out.key" -out "$out" >/dev/null 2>&1
    rm -f "$out.key"
  fi
}

@test "ABI names map to frida-server asset suffixes" {
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/mobile.sh"
    printf "%s %s %s %s\n" \
      "$(mobile_abi_to_arch arm64-v8a)" "$(mobile_abi_to_arch armeabi-v7a)" \
      "$(mobile_abi_to_arch x86)" "$(mobile_abi_to_arch x86_64)"
    mobile_abi_to_arch mips || echo rejected'
  [ "$status" -eq 0 ]
  [ "$output" = "arm64 arm x86 x86_64
rejected" ]
}

@test "proxy CA is written as <subject_hash_old>.0 from PEM" {
  _make_cert "$BATS_TEST_TMPDIR/certs/ca.pem" PEM
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/mobile.sh"
    proxy_ca_prepare "$BATS_TEST_TMPDIR/certs/ca.pem" "$BATS_TEST_TMPDIR/out"'
  [ "$status" -eq 0 ]
  local expected; expected=$(openssl x509 -in "$BATS_TEST_TMPDIR/certs/ca.pem" -noout -subject_hash_old)
  [ "$(basename "$output")" = "$expected.0" ]
  [ -s "$BATS_TEST_TMPDIR/out/$expected.0" ]
}

@test "proxy CA accepts a DER export" {
  _make_cert "$BATS_TEST_TMPDIR/certs/ca.der" DER
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/mobile.sh"
    proxy_ca_prepare "$BATS_TEST_TMPDIR/certs/ca.der" "$BATS_TEST_TMPDIR/out"'
  [ "$status" -eq 0 ]
  local expected; expected=$(openssl x509 -inform DER -in "$BATS_TEST_TMPDIR/certs/ca.der" -noout -subject_hash_old)
  [ "$(basename "$output")" = "$expected.0" ]
  grep -q -- '-----BEGIN CERTIFICATE-----' "$BATS_TEST_TMPDIR/out/$expected.0"
}

@test "proxy CA rejects a file that is not a certificate" {
  printf 'not a cert\n' > "$BATS_TEST_TMPDIR/certs/bad.pem"
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/mobile.sh"
    proxy_ca_prepare "$BATS_TEST_TMPDIR/certs/bad.pem" "$BATS_TEST_TMPDIR/out"'
  [ "$status" -ne 0 ]
  [[ "$output" == *'Not a PEM or DER certificate'* ]]
}

@test "frida-server dry run never downloads or touches the device" {
  cat > "$BIN_DIR/adb" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == devices ]]; then
  printf 'List of devices attached\nemulator-5554\tdevice\n'
fi
EOF
  chmod +x "$BIN_DIR/adb"
  run bash -c '
    source "$ROOT/lib/common.sh"; source "$ROOT/lib/mobile.sh"
    PATH="$BIN_DIR:$PATH" ait_frida_server --device emulator-5554 --dry-run'
  [ "$status" -eq 0 ]
  [[ "$output" == *'would read ro.product.cpu.abi from emulator-5554'* ]]
  [[ "$output" == *'would download and verify frida-server'* ]]
}
