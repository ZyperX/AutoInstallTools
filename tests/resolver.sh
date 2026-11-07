#!/usr/bin/env bash
# Assert the profile/--with/--without resolver behaves as specified.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-$HOME/.local/share/ait}"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/catalog.sh
source "$ROOT/lib/catalog.sh"
bootstrap_yq >/dev/null

fail=0
has() { grep -qx "$2" <<<"$1"; }

minimal=$(resolve_tools minimal '' '')
web=$(resolve_tools web '' '')
mobile=$(resolve_tools mobile '' '')
all=$(resolve_tools all '' '')

# minimal has core/runtime but not recon/web/mobile
has "$minimal" jq        || { echo "RESOLVER: minimal missing jq" >&2; fail=1; }
has "$minimal" subfinder && { echo "RESOLVER: minimal should not include subfinder" >&2; fail=1; }
has "$minimal" objection && { echo "RESOLVER: minimal should not include objection" >&2; fail=1; }

# web includes recon+web tools, not mobile-only
has "$web" subfinder   || { echo "RESOLVER: web missing subfinder" >&2; fail=1; }
has "$web" ffuf        || { echo "RESOLVER: web missing ffuf" >&2; fail=1; }
has "$web" kiterunner || { echo "RESOLVER: web missing api tools (kiterunner)" >&2; fail=1; }
has "$web" gitleaks   || { echo "RESOLVER: web missing code tools (gitleaks)" >&2; fail=1; }
has "$web" objection   && { echo "RESOLVER: web should not include objection" >&2; fail=1; }

# mobile includes mobile tools, not web-only
has "$mobile" objection || { echo "RESOLVER: mobile missing objection" >&2; fail=1; }
has "$mobile" feroxbuster && { echo "RESOLVER: mobile should not include feroxbuster" >&2; fail=1; }

# all is the union (web + mobile + code) but excludes opt-in
has "$all" subfinder  || { echo "RESOLVER: all missing subfinder" >&2; fail=1; }
has "$all" objection  || { echo "RESOLVER: all missing objection" >&2; fail=1; }
has "$all" trivy      || { echo "RESOLVER: all missing trivy" >&2; fail=1; }
has "$all" assetnote  && { echo "RESOLVER: all should exclude opt-in assetnote" >&2; fail=1; }
has "$all" claude-code && { echo "RESOLVER: all should exclude opt-in claude-code" >&2; fail=1; }

# --with adds a tool by name; --without removes by name
has "$(resolve_tools minimal nuclei '')" nuclei || { echo "RESOLVER: --with nuclei failed" >&2; fail=1; }
has "$(resolve_tools web '' amass)" amass        && { echo "RESOLVER: --without amass failed" >&2; fail=1; }
# --with/--without by tag
has "$(resolve_tools api code '')" trivy         || { echo "RESOLVER: --with code tag failed" >&2; fail=1; }
has "$(resolve_tools web '' recon)" subfinder    && { echo "RESOLVER: --without recon tag failed" >&2; fail=1; }

# Per-platform pin maps must be read by key; a map must never be mistaken for a
# scalar sha256 (this caused false checksum failures for caido/jadx/opengrep).
map_sha=$(catalog_tool_field caido-cli sha256.linux_amd64)
scalar_sha=$(catalog_tool_str caido-cli sha256)
[[ "$map_sha" =~ ^[0-9a-f]{64}$ ]] \
  || { echo "RESOLVER: per-platform sha256 map lookup failed" >&2; fail=1; }
[[ -z "$scalar_sha" ]] \
  || { echo "RESOLVER: sha256 map leaked into scalar field" >&2; fail=1; }

if ((fail)); then echo "resolver tests FAILED" >&2; exit 1; fi
echo "resolver tests passed"
