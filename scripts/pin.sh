#!/usr/bin/env bash
# Dev tool: pin version/asset/sha256 for github_release & official_archive tools.
#   scripts/pin.sh <tool> | --all
#
# Uses the GitHub API (asset `.digest` when present) and the release's checksum
# file when GitHub has no digest. Writes the fields back into catalog/tools.yaml
# with yq. Run after a bump; CI verifies every pinned entry has a checksum.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-$HOME/.local/share/ait}"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/catalog.sh
source "$ROOT/lib/catalog.sh"
bootstrap_yq >/dev/null

TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}}"
gh_json() {
  if [[ -n "$TOKEN" ]]; then
    curl -fsSL -H "Authorization: Bearer $TOKEN" "$1"
  else
    curl -fsSL "$1"
  fi
}

_skip_asset() {
  case "$1" in
    *.deb | *.rpm | *.apk | *.msi | *.exe | *.dmg | *.pkg | *.sig | *.asc) return 0 ;;
    *.pem | *.txt | *.json | *.sha256 | *.sha512 | *.sha1 | *.md5) return 0 ;;
    *.minisig | *.pub | *sbom* | *spdx* | *sigstore* | *provenance* | *checksum*) return 0 ;;
  esac
  return 1
}

_asset_priority() {
  case "$1" in
    *.tar.gz | *.tgz) echo 1 ;;
    *.tar.xz) echo 2 ;;
    *.tar.bz2) echo 3 ;;
    *.zip) echo 4 ;;
    *) echo 5 ;;
  esac
}

# _asset_for <release-json> <arch-token> <glob-or-empty> -> best asset name
_asset_for() {
  local json=$1 arch=$2 glob=$3 name best='' bestp=99 p
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ -n "$glob" ]]; then
      # shellcheck disable=SC2053  # glob match against the catalog's pattern
      [[ "$name" == $glob ]] || continue
    else
      _skip_asset "$name" && continue
      local lower=${name,,}
      [[ "$lower" == *linux* ]] || continue
      case "$lower" in *386* | *32bit* | *armv6* | *armv7* | *i686* | *musl*) continue ;; esac
      if [[ "$arch" == amd64 ]]; then
        [[ "$lower" =~ (amd64|x86_64|x64|64bit) ]] || continue
      else
        [[ "$lower" =~ (arm64|aarch64) ]] || continue
      fi
    fi
    p=$(_asset_priority "$name")
    if ((p < bestp)); then best=$name; bestp=$p; fi
  done < <(jq -r '.assets[].name' <<<"$json")
  printf '%s' "$best"
}

_digest() { # json, asset-name -> sha256 hex or empty
  jq -r --arg a "$1" '.assets[] | select(.name==$a) | .digest // ""' <<<"$2" | sed 's/^sha256://'
}

_checksum_asset() { # json -> a checksums asset name or empty
  jq -r '.assets[].name' <<<"$1" | while IFS= read -r n; do
    case "$n" in
      *checksums*.txt | *checksums*.sha256 | *sha256sums*.txt | *.sha256) echo "$n"; break ;;
    esac
  done | head -n1
}

_set() { # yq assignment with yq env vars already exported
  "$YQ" -i "$1" "$TOOLS_YAML"
}

_download_hash() { # url -> sha256 (used only when upstream publishes no digest)
  local tmp; tmp=$(mktemp)
  if curl -fsSL --retry 3 -o "$tmp" "$1"; then
    sha256sum "$tmp" | awk '{print $1}'
  fi
  rm -f -- "$tmp"
}

pin_one() {
  local name=$1 method repo glob json tag
  method=$(catalog_tool_field "$name" method)
  case "$method" in github_release | official_archive) ;; *) echo "skip $name ($method)"; return 0 ;; esac
  repo=$(catalog_tool_field "$name" repo)
  [[ -n "$repo" ]] || { echo "skip $name (no GitHub repo; pin manually)"; return 0; }

  json=$(gh_json "https://api.github.com/repos/$repo/releases/latest") \
    || { echo "FAIL $name (GitHub API)"; return 0; }
  tag=$(jq -r '.tag_name' <<<"$json")
  [[ -n "$tag" && "$tag" != null ]] || { echo "FAIL $name (no tag)"; return 0; }

  glob=$(catalog_tool_str "$name" asset)
  # A scalar `asset` is a glob; turn it into a per-platform map before writing.
  if [[ -n "$glob" ]]; then
    N="$name" _set '(.tools[] | select(.name == strenv(N))).asset = {}'
  fi
  local have_asset=0 have_sum=0 plat arch a dg cfile
  cfile=$(_checksum_asset "$json")
  for plat in linux_amd64:amd64 linux_arm64:arm64; do
    arch=${plat##*:}; plat=${plat%%:*}
    a=$(catalog_tool_field "$name" "asset.$plat")
    [[ -n "$a" ]] || a=$(_asset_for "$json" "$arch" "$glob")
    [[ -n "$a" ]] || continue
    have_asset=1
    N="$name" P="$plat" A="$a" _set '(.tools[] | select(.name == strenv(N))).asset[strenv(P)] = strenv(A)'
    dg=$(_digest "$a" "$json")
    if [[ -z "$dg" && -z "$cfile" ]]; then
      # No digest and no checksum file: hash the asset ourselves (small ones only).
      local size url
      size=$(jq -r --arg a "$a" '.assets[] | select(.name==$a) | .size // 0' <<<"$json")
      url=$(jq -r --arg a "$a" '.assets[] | select(.name==$a) | .browser_download_url' <<<"$json")
      if ((size > 0 && size < 200 * 1024 * 1024)); then
        dg=$(_download_hash "$url")
      fi
    fi
    if [[ -n "$dg" ]]; then
      have_sum=1
      N="$name" P="$plat" D="$dg" _set '(.tools[] | select(.name == strenv(N))).sha256[strenv(P)] = strenv(D)'
    fi
    echo "  $name/$plat -> $a${dg:+ (sha256)}"
  done

  if [[ -n "$cfile" ]]; then
    N="$name" C="$cfile" _set '(.tools[] | select(.name == strenv(N))).checksum_file = strenv(C)'
    have_sum=1
  fi

  if ((have_asset && have_sum)); then
    N="$name" TAG="$tag" _set '(.tools[] | select(.name == strenv(N))).version = strenv(TAG)'
    echo "pinned $name -> $tag"
  else
    echo "FAIL $name: no per-arch asset/digest or checksum file (left unpinned)"
  fi
}

main() {
  [[ $# -ge 1 ]] || { echo "usage: pin.sh <tool>|--all" >&2; exit 2; }
  if [[ "$1" == --all ]]; then
    local n
    while IFS= read -r n; do
      pin_one "$n"
    done < <(catalog_tool_names)
  else
    pin_one "$1"
  fi
}
main "$@"
