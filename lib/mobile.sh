#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR/DRY_RUN provided by lib/common.sh
# Mobile helpers: adb discovery (including WSL hints), frida-server bootstrap and
# proxy CA preparation for Android. Nothing here requires a rooted host; device
# actions use adb, and root on the device is only used when `su` is available.

# Map an Android ABI (ro.product.cpu.abi) to the frida-server asset suffix.
mobile_abi_to_arch() {
  case "$1" in
    arm64-v8a | arm64) echo arm64 ;;
    armeabi-v7a | armeabi | arm) echo arm ;;
    x86) echo x86 ;;
    x86_64 | x86-64) echo x86_64 ;;
    *) return 1 ;;
  esac
}

# mobile_adb_devices: one serial per connected (state=device) device.
mobile_adb_devices() {
  command -v adb >/dev/null 2>&1 || return 1
  adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" { print $1 }'
}

# mobile_adb_pick_serial [requested]: print one usable serial or explain why not.
mobile_adb_pick_serial() {
  local requested=${1:-} serial
  command -v adb >/dev/null 2>&1 || { err 'adb is not installed (ait install --with platform-tools)'; return 1; }

  if [[ -n "$requested" ]]; then
    if ! adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" { print $1 }' | grep -Fxq -- "$requested"; then
      err "Device $requested is not connected/authorized (adb devices)"
      return 1
    fi
    printf '%s\n' "$requested"
    return 0
  fi

  local -a devs=()
  mapfile -t devs < <(mobile_adb_devices)
  case ${#devs[@]} in
    0)
      err 'No adb device is connected. Connect USB with debugging enabled, or use adb connect <phone-ip>:5555.'
      return 1
      ;;
    1) printf '%s\n' "${devs[0]}" ;;
    *)
      err 'More than one device is connected; pass --device SERIAL:'
      printf '  %s\n' "${devs[@]}" >&2
      return 1
      ;;
  esac
}

# mobile_adb_report: doctor-style status, plus WSL-specific reachability hints.
mobile_adb_report() {
  command -v adb >/dev/null 2>&1 || return 0
  local serial state any=0
  while read -r serial state; do
    [[ -z "$serial" ]] && continue
    any=1
    case "$state" in
      device) ok "adb: $serial connected" ;;
      unauthorized) warn "adb: $serial unauthorized (accept the debugging prompt)" ;;
      offline) warn "adb: $serial offline (reconnect the cable / restart adb)" ;;
      *) warn "adb: $serial $state" ;;
    esac
  done < <(adb devices 2>/dev/null | awk 'NR > 1 && NF >= 2 { print $1, $2 }')
  ((any)) || warn 'adb: no devices connected'

  if is_wsl; then
    if ! ((any)); then
      warn 'WSL: attach USB with usbipd-win (usbipd list; usbipd attach --wsl --busid <busid>)'
      warn 'WSL: or enable wireless debugging and run adb connect <phone-ip>:5555'
    fi
    warn 'WSL: mirrored networking lets WSL reuse Windows adb: export ADB_SERVER_SOCKET=tcp:localhost:5037'
    warn 'WSL: only one adb server may own port 5037; run adb in WSL or Windows, not both'
  fi
}

# --- frida-server ---------------------------------------------------------
_frida_usage() {
  cat <<'EOF'
Usage: ait frida-server [--device SERIAL] [--dry-run]

Reads the host frida version and the device ABI, downloads the matching
frida-server release (sha256 from the GitHub API), pushes it to
/data/local/tmp, starts it, and confirms with frida-ps.
EOF
}

# _frida_release_json <version> -> release JSON or non-zero.
_frida_release_json() {
  local version=$1
  retry curl -fsSL "https://api.github.com/repos/frida/frida/releases/tags/$version"
}

# _frida_download_asset <json> <asset-name> <dest> -> 0 on verified download.
_frida_download_asset() {
  local json=$1 asset=$2 dest=$3 url digest expected actual
  url=$(jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$json")
  [[ -n "$url" ]] || { err "release $asset not found"; return 1; }
  digest=$(jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .digest // empty' <<<"$json")
  [[ -n "$digest" ]] || { err "upstream publishes no digest for $asset; refusing to install unverified"; return 1; }

  retry curl -fL --retry 3 -o "$dest" "$url" || { err "download failed: $url"; return 1; }
  expected=${digest#sha256:}
  actual=$(sha256sum "$dest" | awk '{ print $1 }')
  if [[ "$actual" != "$expected" ]]; then
    rm -f -- "$dest"
    err "sha256 mismatch for $asset (expected $expected, got $actual)"
    return 1
  fi
  ok "Verified $asset (sha256)"
}

# _frida_device_has_root <serial>
_frida_device_has_root() {
  local serial=$1
  adb -s "$serial" shell 'su -c id' 2>/dev/null | tr -d '\r' | grep -q 'uid=0'
}

# _frida_start <serial> <remote-binary>
_frida_start() {
  local serial=$1 remote=$2
  # Stop an older server so the pushed binary can be replaced and restarted.
  if _frida_device_has_root "$serial"; then
    adb -s "$serial" shell \
      "su -c 'killall frida-server 2>/dev/null || pkill frida-server 2>/dev/null || true; sleep 1; $remote -D'" \
      >/dev/null 2>&1 || true
  else
    warn 'Device has no su; starting frida-server as the shell user (works on debuggable/rooted builds only).'
    adb -s "$serial" shell \
      "killall frida-server 2>/dev/null || pkill frida-server 2>/dev/null || true; sleep 1; $remote -D" \
      >/dev/null 2>&1 || true
  fi
}

ait_frida_server() (
  local device='' host_ver arch abi serial remote='/data/local/tmp/frida-server'
  while (($#)); do case "$1" in
    --device) device=$2; shift 2 ;;
    --device=*) device=${1#*=}; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h | --help) _frida_usage; exit 0 ;;
    *) die "Unknown option: $1 (try: ait frida-server --help)" ;;
  esac; done

  [[ ${DRY_RUN:-0} == 1 ]] || require_linux
  command -v adb >/dev/null 2>&1 || die 'adb is required: ait install --profile mobile --with platform-tools'
  [[ ${DRY_RUN:-0} == 1 ]] || command -v frida >/dev/null 2>&1 || die 'frida is not installed: ait install --with frida-tools'
  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    die 'curl and jq are required for the GitHub release API'
  fi
  command -v xz >/dev/null 2>&1 || die 'xz is required to unpack frida-server'

  host_ver=$(frida --version 2>/dev/null || true)
  serial=$(mobile_adb_pick_serial "$device") || exit 1

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    would "read ro.product.cpu.abi from $serial"
    would "download and verify frida-server ${host_ver:-<host-version>} for that ABI"
    would "push it to $remote, chmod 755 and start it (su when available)"
    would "confirm with frida-ps -D $serial"
    exit 0
  fi

  [[ -n "$host_ver" ]] || die 'Could not read the host frida version (frida --version).'
  abi=$(adb -s "$serial" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r' | head -n1)
  arch=$(mobile_abi_to_arch "$abi") || die "Unsupported device ABI: ${abi:-unknown}"
  log "Host frida $host_ver, device $serial ($abi)"

  # Skip the whole round trip when the same server version is already live.
  local device_ver
  device_ver=$(adb -s "$serial" shell "$remote --version" 2>/dev/null | tr -d '\r' | head -n1)
  if [[ "$device_ver" == "$host_ver" ]] && frida-ps -D "$serial" >/dev/null 2>&1; then
    ok "frida-server $host_ver already running on $serial"
    exit 0
  fi

  local tmp asset json
  tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
  json=$(_frida_release_json "$host_ver") || die "No frida release tagged $host_ver"
  asset="frida-server-$host_ver-android-$arch.xz"
  _frida_download_asset "$json" "$asset" "$tmp/frida-server.xz" || exit 1
  xz -dc "$tmp/frida-server.xz" > "$tmp/frida-server" || die 'Could not unpack frida-server.xz'

  adb -s "$serial" push "$tmp/frida-server" "$remote" >/dev/null || die 'adb push failed'
  adb -s "$serial" shell "chmod 755 $remote" >/dev/null || die 'chmod on the device failed'
  _frida_start "$serial" "$remote"

  for _ in 1 2 3 4 5; do
    if frida-ps -D "$serial" >/dev/null 2>&1 || frida-ps -U >/dev/null 2>&1; then
      ok "frida-server $host_ver is running on $serial"
      exit 0
    fi
    sleep 1
  done
  err "frida-server started but frida-ps cannot see $serial; check su/root and that port 27042 is free"
  exit 1
)

# --- proxy CA -------------------------------------------------------------
_proxy_ca_usage() {
  cat <<'EOF'
Usage: ait proxy-ca --burp|--caido|--mitmproxy [CERT] [--out DIR]

Normalises the CA to PEM, names it <subject_hash_old>.0 (what Android looks
for) and prints install steps for the user and system stores. Export the CA
from the proxy first; mitmproxy's default cert is found automatically.
EOF
}

# proxy_ca_prepare <cert> <outdir>: writes <hash>.0, prints its path.
proxy_ca_prepare() {
  local cert=$1 outdir=$2 pem hash out
  [[ -f "$cert" ]] || { err "Certificate not found: $cert"; return 1; }
  command -v openssl >/dev/null 2>&1 || { err 'openssl is required'; return 1; }
  mkdir -p "$outdir" || return 1

  pem=$(mktemp); trap 'rm -f -- "$pem"' RETURN
  if grep -q -- '-----BEGIN CERTIFICATE-----' "$cert"; then
    cp -- "$cert" "$pem"
  elif ! openssl x509 -inform DER -in "$cert" -out "$pem" 2>/dev/null; then
    err "Not a PEM or DER certificate: $cert"; return 1
  fi

  hash=$(openssl x509 -in "$pem" -noout -subject_hash_old 2>/dev/null) || {
    err "Could not parse the certificate: $cert"; return 1; }
  hash=${hash%%$'\n'*}
  [[ -n "$hash" ]] || { err "Could not compute subject_hash_old for $cert"; return 1; }

  out="$outdir/$hash.0"
  cp -- "$pem" "$out" || return 1
  printf '%s\n' "$out"
}

# _proxy_default_cert <kind>: likely export paths, newest first.
_proxy_default_cert() {
  local kind=$1
  case "$kind" in
    mitmproxy) printf '%s\n' "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" ;;
    burp)
      printf '%s\n' "$HOME/Downloads/cacert.der" "$HOME/Downloads/cacert.pem" \
        "$HOME/Downloads/ca.crt" "$PWD/cacert.der" "$PWD/cacert.pem"
      ;;
    caido)
      printf '%s\n' "$HOME/Downloads/ca.crt" "$HOME/Downloads/ca.pem" \
        "$HOME/.caido/ca.pem" "$PWD/ca.crt" "$PWD/ca.pem"
      ;;
  esac
}

_proxy_print_steps() {
  local kind=$1 out=$2 base
  base=$(basename -- "$out")
  cat <<EOF

Prepared: $out
Filename is <subject_hash_old>.0, the name Android expects.

User store (no root, works for browsers and apps that trust user CAs):
  1. adb push "$out" /sdcard/Download/$base
  2. On the phone: Settings > Security > Encryption & credentials >
     Install a certificate > CA certificate > Install anyway > $base
  3. Verify: Settings > Security > Trusted credentials > User

System store (root; needed by apps that ignore user CAs):
  Android < 14 (writable /system):
    adb root
    adb remount
    adb push "$out" /system/etc/security/cacerts/$base
    adb shell chmod 644 /system/etc/security/cacerts/$base
    adb reboot
  Android 14+ (APEX conscrypt, /system is read-only):
    adb root
    adb shell mkdir -p /data/local/tmp/ait-cacerts
    adb push "$out" /data/local/tmp/ait-cacerts/$base
    adb shell 'mount -t tmpfs tmpfs /system/etc/security/cacerts &&
      cp /apex/com.android.conscrypt/cacerts/* /system/etc/security/cacerts/ &&
      cp /data/local/tmp/ait-cacerts/* /system/etc/security/cacerts/ &&
      chown root:root /system/etc/security/cacerts/* &&
      chmod 644 /system/etc/security/cacerts/*'
  The tmpfs mount is lost on reboot; use a Magisk module (for example
  MagiskTrustUserCerts) for persistence. Some apps also pin certificates in
  code, which no store change can bypass.

Source: $kind. Keep this CA private: anyone holding the key can intercept
traffic that trusts it.
EOF
}

ait_proxy_ca() (
  local kind='' cert='' outdir=$PWD
  while (($#)); do case "$1" in
    --burp) kind=burp; shift ;;
    --caido) kind=caido; shift ;;
    --mitmproxy) kind=mitmproxy; shift ;;
    --out) outdir=$2; shift 2 ;;
    --out=*) outdir=${1#*=}; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h | --help) _proxy_ca_usage; exit 0 ;;
    -*) die "Unknown option: $1 (try: ait proxy-ca --help)" ;;
    *) cert=$1; shift ;;
  esac; done

  [[ -n "$kind" ]] || die 'Pick a proxy: --burp, --caido or --mitmproxy'
  if [[ -z "$cert" ]]; then
    local candidate
    while IFS= read -r candidate; do
      [[ -f "$candidate" ]] && { cert=$candidate; break; }
    done < <(_proxy_default_cert "$kind")
  fi
  [[ -n "$cert" ]] || die "No $kind certificate found. Export it from the proxy and pass the path: ait proxy-ca --$kind /path/to/cert"

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    would "convert $cert to PEM and write $(basename -- "${cert%.*}").0 (subject_hash_old) in $outdir"
    exit 0
  fi

  local out
  out=$(proxy_ca_prepare "$cert" "$outdir") || exit 1
  ok "Wrote $out"
  _proxy_print_steps "$kind" "$out"
)
