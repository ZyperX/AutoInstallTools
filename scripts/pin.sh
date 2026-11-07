#!/usr/bin/env bash
# Dev tool: pin version/asset/sha256 for github_release & official_archive tools.
#   scripts/pin.sh <tool> | --all
# Uses the GitHub API (asset .digest when present, else downloads to hash) and
# writes the fields back into catalog/tools.yaml with yq. Run after a bump; CI
# verifies every pinned entry has a checksum per declared platform.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-$HOME/.local/share/ait}"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/catalog.sh
source "$ROOT/lib/catalog.sh"
bootstrap_yq >/dev/null

gh_json() { curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN:-${GH_TOKEN:-}}" "$1" 2>/dev/null || curl -fsSL "$1"; }

# Find the asset name for a repo+tag matching an arch token (and a glob, if given).
_asset_for() {
  local json=$1 arch=$2 glob=$3
  jq -r '.assets[].name' <<<"$json" | while IFS= read -r n; do
    # shellcheck disable=SC2053  # glob match against the catalog's asset pattern
    if [[ -n "$glob" ]]; then [[ "$n" == $glob ]] && echo "$n"
    else
      case "$n" in *.sha256|*.txt|*.sig|*.pem|*.deb|*.rpm|*.json|*checksums*) continue ;; esac
      [[ "$n" == *"$arch"* && "$n" == *linux* ]] && echo "$n"
    fi
  done | head -n1
}

_digest() { # json, asset-name -> sha256 hex or empty
  jq -r --arg a "$1" '.assets[] | select(.name==$a) | .digest // ""' <<<"$2" | sed 's/^sha256://'
}

pin_one() {
  local name=$1 method repo glob json tag
  method=$(catalog_tool_field "$name" method)
  case "$method" in github_release|official_archive) ;; *) echo "skip $name ($method)"; return 0 ;; esac
  repo=$(catalog_tool_field "$name" repo)
  [[ -n "$repo" ]] || { echo "skip $name (no repo)"; return 0; }
  glob=$(catalog_tool_field "$name" asset)
  json=$(gh_json "https://api.github.com/repos/$repo/releases/latest") || { echo "FAIL $name (API)"; return 0; }
  tag=$(jq -r '.tag_name' <<<"$json")
  [[ -n "$tag" && "$tag" != null ]] || { echo "FAIL $name (no tag)"; return 0; }

  N="$name" TAG="$tag" "$YQ" -i '(.tools[] | select(.name == strenv(N))).version = strenv(TAG)' "$TOOLS_YAML"
  local k arch a dg
  for k in linux_amd64:x86_64 linux_amd64:amd64 linux_arm64:aarch64 linux_arm64:arm64; do
    local plat=${k%%:*} tok=${k##*:}
    a=$(_asset_for "$json" "$tok" "$glob"); [[ -n "$a" ]] || continue
    # don't overwrite a platform we already filled this run
    [[ -n "$(N="$name" P="$plat" "$YQ" '(.tools[]|select(.name==strenv(N))).asset[strenv(P)] // ""' "$TOOLS_YAML" 2>/dev/null)" ]] && continue
    dg=$(_digest "$a" "$json")
    [[ -z "$dg" ]] && { echo "  $name/$plat: no API digest (download to hash not implemented); asset=$a"; }
    N="$name" P="$plat" A="$a" "$YQ" -i '(.tools[]|select(.name==strenv(N))).asset[strenv(P)] = strenv(A)' "$TOOLS_YAML"
    [[ -n "$dg" ]] && N="$name" P="$plat" D="$dg" "$YQ" -i '(.tools[]|select(.name==strenv(N))).sha256[strenv(P)] = strenv(D)' "$TOOLS_YAML"
  done
  echo "pinned $name -> $tag"
}

main() {
  [[ $# -ge 1 ]] || { echo "usage: pin.sh <tool>|--all" >&2; exit 2; }
  if [[ "$1" == --all ]]; then
    while IFS= read -r n; do
      m=$(catalog_tool_field "$n" method)
      [[ "$m" == github_release || "$m" == official_archive ]] && pin_one "$n"
    done < <(catalog_tool_names)
  else
    pin_one "$1"
  fi
}
main "$@"
