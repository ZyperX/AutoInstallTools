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
full=$(resolve_tools full '' '')

# minimal has core/runtime but not recon/web/mobile
has "$minimal" jq        || { echo "RESOLVER: minimal missing jq" >&2; fail=1; }
has "$minimal" subfinder && { echo "RESOLVER: minimal should not include subfinder" >&2; fail=1; }
has "$minimal" objection && { echo "RESOLVER: minimal should not include objection" >&2; fail=1; }

# web includes recon+web tools, not mobile-only
has "$web" subfinder   || { echo "RESOLVER: web missing subfinder" >&2; fail=1; }
has "$web" ffuf        || { echo "RESOLVER: web missing ffuf" >&2; fail=1; }
has "$web" objection   && { echo "RESOLVER: web should not include objection" >&2; fail=1; }

# mobile includes mobile tools, not web-only
has "$mobile" objection || { echo "RESOLVER: mobile missing objection" >&2; fail=1; }
has "$mobile" feroxbuster && { echo "RESOLVER: mobile should not include feroxbuster" >&2; fail=1; }

# full is the union (web + mobile + code) but excludes opt-in
has "$full" subfinder  || { echo "RESOLVER: full missing subfinder" >&2; fail=1; }
has "$full" objection  || { echo "RESOLVER: full missing objection" >&2; fail=1; }
has "$full" trivy      || { echo "RESOLVER: full missing trivy" >&2; fail=1; }
has "$full" assetnote  && { echo "RESOLVER: full should exclude opt-in assetnote" >&2; fail=1; }
has "$full" claude-code && { echo "RESOLVER: full should exclude opt-in claude-code" >&2; fail=1; }

# --with adds a tool by name; --without removes by name
has "$(resolve_tools minimal nuclei '')" nuclei || { echo "RESOLVER: --with nuclei failed" >&2; fail=1; }
has "$(resolve_tools web '' amass)" amass        && { echo "RESOLVER: --without amass failed" >&2; fail=1; }
# --with/--without by tag
has "$(resolve_tools api code '')" trivy         || { echo "RESOLVER: --with code tag failed" >&2; fail=1; }
has "$(resolve_tools web '' recon)" subfinder    && { echo "RESOLVER: --without recon tag failed" >&2; fail=1; }

if ((fail)); then echo "resolver tests FAILED" >&2; exit 1; fi
echo "resolver tests passed"
