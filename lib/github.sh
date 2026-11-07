#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR is provided by lib/common.sh
# Install a project's latest GitHub release binary.
#
# Picks the right asset for the host architecture, skips packaging/signature/
# checksum side-files and other OSes, prefers archives over raw binaries, and
# verifies the download against an upstream checksum when one is published (B5).

# Release tools refreshed by update.sh.
# shellcheck disable=SC2034  # consumed by update.sh, which sources this file
GITHUB_UPDATABLE=(
  "sharkdp/bat" "sharkdp/fd" "eza-community/eza" "mikefarah/yq" "junegunn/fzf"
  "muesli/duf" "jesseduffield/lazydocker" "wagoodman/dive" "aquasecurity/trivy"
  "anchore/syft" "anchore/grype" "derailed/k9s" "ahmetb/kubectx" "owasp-amass/amass"
)

# Regex (used case-insensitively) matching assets for the host CPU.
_gh_arch_regex() {
  case "$(uname -m)" in
    x86_64) echo 'x86[_-]?64|amd64|x64|64bit' ;;
    aarch64 | arm64) echo 'aarch64|arm64' ;;
    *) return 1 ;;
  esac
}

# github_install_latest <repo> [binary-name] [dest-path]
github_install_latest() (
  local repo=$1
  local binname=${2:-${repo##*/}}
  local dest=${3:-$BIN_DIR/$binname}
  local inc json choice name url

  if [[ ${FORCE_INSTALL:-0} != 1 ]] && command -v "$binname" >/dev/null 2>&1; then
    ok "$binname already installed; skipping"
    return 0
  fi

  # Short-circuit before any dependency or network access so --dry-run is truthful.
  if dryrun; then would "install $binname from the latest $repo release to $dest"; return 0; fi

  inc=$(_gh_arch_regex) || { record_failure "$binname" "unsupported CPU architecture $(uname -m)"; return 0; }
  if ! { command -v curl >/dev/null && command -v jq >/dev/null; }; then
    record_failure "$binname" 'curl and jq are required for GitHub releases'; return 0
  fi

  json=$(retry curl -fsSL "https://api.github.com/repos/$repo/releases/latest") || {
    record_failure "$binname" 'could not query the GitHub release API'; return 0; }

  # Choose the best asset: right arch, Linux, not a side-file; prefer archives.
  choice=$(jq -r --arg inc "$inc" '
    def prio:
      if test("\\.tar\\.gz$|\\.tgz$";"i") then 1
      elif test("\\.tar\\.xz$";"i") then 2
      elif test("\\.tar\\.bz2$";"i") then 3
      elif test("\\.zip$";"i") then 4
      else 5 end;
    [ .assets[]
      | select(.name | test($inc;"i"))
      | select(.name | test("linux";"i"))
      | select((.name | test("(\\.deb|\\.rpm|\\.apk|\\.msi|\\.exe|\\.dmg|\\.pkg|\\.sig|\\.asc|\\.pem|\\.txt|\\.json|\\.sha256|\\.sha512|\\.sha1|\\.md5|\\.minisig|\\.pub|sbom|spdx|sigstore|provenance|checksum)";"i")) | not)
      | {name: .name, url: .browser_download_url, p: (.name | prio)} ]
    | sort_by(.p, .name) | .[0] // empty | "\(.name)\t\(.url)"' <<<"$json")

  [[ -n "$choice" ]] || { record_failure "$binname" "no matching Linux release asset for $(uname -m)"; return 0; }
  name=${choice%%$'\t'*}; url=${choice#*$'\t'}

  local tmp; tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
  retry curl -fL --retry 3 -o "$tmp/asset" "$url" || { record_failure "$binname" 'release download failed'; return 0; }

  _gh_verify_checksum "$json" "$name" "$tmp/asset" "$binname" || return 0
  gh_install_from_file "$tmp/asset" "$name" "$binname" "$dest" || return 0
  ok "Installed $binname ($name)"
)

# gh_install_from_file <file> <asset-name> <binname> <dest>
# Extract (or copy) a downloaded asset and place the executable at dest.
gh_install_from_file() {
  local file=$1 aname=$2 binname=$3 dest=$4 ex bin
  ex=$(mktemp -d)
  case "$aname" in
    *.tar.gz | *.tgz) tar -xzf "$file" -C "$ex" ;;
    *.tar.xz) tar -xJf "$file" -C "$ex" ;;
    *.tar.bz2) tar -xjf "$file" -C "$ex" ;;
    *.zip) unzip -q "$file" -d "$ex" ;;
    *.gz) gunzip -c "$file" > "$ex/$binname" ;;
    *) cp "$file" "$ex/$binname" ;;
  esac || { rm -rf -- "$ex"; record_failure "$binname" 'could not extract release asset'; return 1; }

  bin=$(find "$ex" -type f -name "$binname" 2>/dev/null | head -n1)
  [[ -z "$bin" ]] && bin=$(find "$ex" -type f -name "${binname}*" ! -name '*.*' 2>/dev/null | head -n1)
  [[ -z "$bin" ]] && bin=$(find "$ex" -type f ! -name '*.*' -size +20k 2>/dev/null | head -n1)
  [[ -n "$bin" ]] || { rm -rf -- "$ex"; record_failure "$binname" 'could not identify executable in asset'; return 1; }

  install -D -m 0755 "$bin" "$dest" || { rm -rf -- "$ex"; record_failure "$binname" 'could not place executable'; return 1; }
  rm -rf -- "$ex"
  return 0
}

# _gh_verify_checksum <release-json> <asset-name> <file> <binname>
# Verifies <file> against an upstream checksum if the release publishes one.
# Returns non-zero (and records a failure) only on an actual mismatch.
_gh_verify_checksum() {
  local json=$1 name=$2 file=$3 binname=$4 csum_url expected actual ctmp
  csum_url=$(jq -r --arg n "$name" '.assets[] | select(.name == ($n + ".sha256")) | .browser_download_url' <<<"$json" | head -n1)
  [[ -z "$csum_url" ]] && csum_url=$(jq -r '
    .assets[] | select(.name | test("checksum|sha256sum|sha256";"i"))
    | select(.name | test("\\.(txt|sha256|sha256sum)$";"i")) | .browser_download_url' <<<"$json" | head -n1)

  if [[ -z "$csum_url" ]]; then
    warn "$binname: no upstream checksum published; installing unverified"
    return 0
  fi

  ctmp=$(mktemp)
  if ! curl -fsSL -o "$ctmp" "$csum_url"; then
    rm -f -- "$ctmp"; warn "$binname: could not fetch checksum; installing unverified"; return 0
  fi
  expected=$(grep -iF -- "$name" "$ctmp" | awk '{print $1}' | head -n1)
  [[ -z "$expected" ]] && expected=$(awk 'NF==1{print $1; exit} {print $1; exit}' "$ctmp")
  rm -f -- "$ctmp"

  actual=$(sha256sum "$file" | awk '{print $1}')
  if [[ -n "$expected" && "$expected" != "$actual" ]]; then
    record_failure "$binname" 'release checksum verification failed'
    return 1
  fi
  ok "$binname: checksum verified"
  return 0
}
