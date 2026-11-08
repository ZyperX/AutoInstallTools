#!/usr/bin/env bash
# Eclipse Temurin JDK 21 installer. The Adoptium assets API returns the binary
# URL and SHA-256 for the selected Linux architecture.

_java_arch() {
  case "$(uname -m)" in
    x86_64) printf 'x64\n' ;;
    aarch64 | arm64) printf 'aarch64\n' ;;
    *) return 1 ;;
  esac
}

_java21_ready() {
  command -v java >/dev/null 2>&1 || return 1
  java -version 2>&1 | head -n1 | grep -Eq 'version "21([.+]|$)|openjdk 21([.+]|$)'
}

install_jdk21() (
  local arch api json url sha name root opt tmp
  if [[ ${FORCE_INSTALL:-0} != 1 ]] && _java21_ready; then
    ok 'JDK 21 already present; skipping'
    return 0
  fi
  if dryrun; then
    would 'download and verify the latest Eclipse Temurin JDK 21 into user space'
    return 0
  fi
  arch=$(_java_arch) || { record_failure jdk "unsupported CPU architecture $(uname -m)"; return 0; }
  if ! command -v curl >/dev/null || ! command -v jq >/dev/null; then
    record_failure jdk 'curl and jq are required for the Adoptium API'; return 0;
  fi
  api="https://api.adoptium.net/v3/assets/latest/21/hotspot?architecture=$arch&heap_size=normal&image_type=jdk&jvm_impl=hotspot&os=linux&page_size=1&project=jdk&vendor=eclipse"
  json=$(retry curl -fsSL "$api") || { record_failure jdk 'Adoptium API request failed'; return 0; }
  url=$(jq -r '.[0].binary.package.link // empty' <<<"$json")
  sha=$(jq -r '.[0].binary.package.checksum // empty' <<<"$json")
  name=$(jq -r '.[0].binary.package.name // empty' <<<"$json")
  [[ -n "$url" && "$name" == *.tar.gz && "$sha" =~ ^[[:xdigit:]]{64}$ ]] || {
    record_failure jdk 'Adoptium returned no usable archive and SHA-256'; return 0;
  }

  tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
  retry curl -fL --retry 3 -o "$tmp/$name" "$url" || { record_failure jdk 'JDK download failed'; return 0; }
  verify_sha256 "$tmp/$name" "$sha" || { record_failure jdk 'JDK SHA-256 verification failed'; return 0; }
  mkdir -p "$tmp/extract" "$BOOTSTRAP_HOME/opt" "$BIN_DIR"
  tar -xzf "$tmp/$name" -C "$tmp/extract" || { record_failure jdk 'JDK extraction failed'; return 0; }
  root=$(find "$tmp/extract" -type f -path '*/bin/java' -print -quit)
  [[ -n "$root" ]] || { record_failure jdk 'JDK archive does not contain bin/java'; return 0; }
  root=${root%/bin/java}
  opt="$BOOTSTRAP_HOME/opt/jdk-21"
  rm -rf -- "$opt"
  mv -- "$root" "$opt" || { record_failure jdk 'could not place JDK in managed directory'; return 0; }
  local executable
  for executable in "$opt"/bin/*; do
    [[ -x "$executable" && -f "$executable" ]] || continue
    ln -sf -- "$executable" "$BIN_DIR/${executable##*/}"
  done
  ok "Installed Temurin JDK 21 ($name)"
)
