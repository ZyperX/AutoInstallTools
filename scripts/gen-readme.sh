#!/usr/bin/env bash
# shellcheck disable=SC2016  # Markdown backticks are literal, not command substitution
# Generate the README tool catalog from catalog/tools.yaml between
# <!-- catalog:start --> and <!-- catalog:end -->.
#
#   scripts/gen-readme.sh            print the generated block
#   scripts/gen-readme.sh --write    replace the block in README.md
#   scripts/gen-readme.sh --check    exit 1 when README.md is stale
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-$HOME/.local/share/ait}"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/platform.sh
source "$ROOT/lib/platform.sh"
# shellcheck source=lib/catalog.sh
source "$ROOT/lib/catalog.sh"
bootstrap_yq >/dev/null

README="$ROOT/README.md"
MODE=${1:-print}
case "$MODE" in
  --write | --check | print) ;;
  *) die "usage: $0 [--write|--check]" ;;
esac

_title() {
  case "$1" in
    core) echo 'Core & everyday CLI' ;;
    runtime) echo 'Runtimes' ;;
    recon) echo 'Recon & attack-surface mapping' ;;
    proxy) echo 'Intercepting proxies' ;;
    discovery) echo 'Content discovery & fuzzing' ;;
    vuln) echo 'Vulnerability scanning & exploitation' ;;
    api) echo 'API, GraphQL & auth' ;;
    js-secrets) echo 'JavaScript, secrets & source' ;;
    sast-sca) echo 'SAST & SCA' ;;
    android) echo 'Android' ;;
    ios) echo 'iOS (host side)' ;;
    reversing) echo 'Reverse engineering' ;;
    wordlists) echo 'Wordlists & payloads' ;;
    cloud) echo 'Cloud & Kubernetes' ;;
    container) echo 'Containers' ;;
    ai) echo 'AI assistants' ;;
    *) echo "$1" ;;
  esac
}

_method() {
  case "$1" in
    github_release) echo 'release' ;;
    official_archive) echo 'official archive' ;;
    git_venv) echo 'git + venv' ;;
    wget_mirror) echo 'mirror' ;;
    *) echo "$1" ;;
  esac
}

# Link a tool to its upstream when the catalog gives us one.
_link() { # name repo git pypi npm crate
  local name=$1 repo=$2 git=$3 pypi=$4 npm=$5 crate=$6 url=''
  if [[ "$repo" != - && -n "$repo" ]]; then url="https://github.com/$repo"
  elif [[ "$git" != - && -n "$git" ]]; then url=${git%.git}
  elif [[ "$pypi" != - && -n "$pypi" ]]; then url="https://pypi.org/project/$pypi/"
  elif [[ "$npm" != - && -n "$npm" ]]; then url="https://www.npmjs.com/package/$npm"
  elif [[ "$crate" != - && -n "$crate" ]]; then url="https://crates.io/crates/$crate"
  fi
  if [[ -n "$url" ]]; then printf '[%s](%s)' "$name" "$url"; else printf '`%s`' "$name"; fi
}

# profiles_for <tags-csv> <opt-in>: comma list of matching profiles or "opt".
profiles_for() {
  local tagcsv=$1 optin=$2 p matched='' have
  if [[ "$optin" == true ]]; then printf 'opt'; return 0; fi
  for p in $(catalog_profiles); do
    have=",$tagcsv,"
    local want
    for want in $(catalog_profile_tags "$p"); do
      [[ "$have" == *",$want,"* ]] && { matched+="${matched:+, }$p"; break; }
    done
  done
  printf '%s' "${matched:-—}"
}

tsv=$(q '.tools[] | [
  .name, .desc, .category, .method, (.tags | join(",")), (.opt_in // false),
  (.repo // "-"), (.git // "-"), (.pypi // "-"), (.npm // "-"), (.crate // "-")
] | @tsv' "$TOOLS_YAML")

CATEGORY_ORDER='core runtime recon proxy discovery vuln api js-secrets sast-sca android ios reversing wordlists cloud container ai'
declare -A rows=()
while IFS=$'\t' read -r name desc category method tags optin repo git pypi npm crate; do
  [[ -z "$name" ]] && continue
  desc=${desc//|/\\|}
  rows[$category]+="| $(_link "$name" "$repo" "$git" "$pypi" "$npm" "$crate") | $desc | $(_method "$method") | $(profiles_for "$tags" "$optin") |"$'\n'
done <<< "$tsv"

tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT
{
  printf '<!-- catalog:start -->\n'
  printf '> Generated from `catalog/tools.yaml` by `scripts/gen-readme.sh`; do not edit by hand.\n'
  printf '> **Method** is how a tool is installed; **Default** lists profiles that select it (`opt` = only via `--with`).\n\n'
  for category in $CATEGORY_ORDER; do
    [[ -n "${rows[$category]:-}" ]] || continue
    printf '### %s\n\n' "$(_title "$category")"
    printf '| Tool | What it is for | Method | Default |\n|---|---|---|---|\n'
    printf '%s' "${rows[$category]}" | sort
    printf '\n'
  done
  printf '<!-- catalog:end -->\n'
} > "$tmp"

case "$MODE" in
  print) cat "$tmp" ;;
  --check)
    current=$(awk '/<!-- catalog:start -->/{f=1} f; /<!-- catalog:end -->/{f=0}' "$README")
    if [[ "$current" != "$(cat "$tmp")" ]]; then
      err 'README catalog tables are stale; run scripts/gen-readme.sh --write'
      diff -u <(printf '%s\n' "$current") "$tmp" || true
      exit 1
    fi
    ok 'README catalog tables are up to date'
    ;;
  --write)
    out=$(mktemp)
    awk -v block="$tmp" '
      /<!-- catalog:start -->/ {
        while ((getline line < block) > 0) print line
        skip = 1
        next
      }
      /<!-- catalog:end -->/ { skip = 0; next }
      !skip { print }
    ' "$README" > "$out"
    mv -- "$out" "$README"
    ok "updated $README"
    ;;
esac
