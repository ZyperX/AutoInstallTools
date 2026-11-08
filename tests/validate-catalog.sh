#!/usr/bin/env bash
# Validate catalog/tools.yaml against the schema: required fields, <=48-char
# descriptions, known methods, method-specific keys, unique names, known tags.
# Uses a single yq pass for speed.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-$HOME/.local/share/ait}"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/catalog.sh
source "$ROOT/lib/catalog.sh"
bootstrap_yq >/dev/null

fail=0
bad() { echo "SCHEMA: $*" >&2; fail=1; }
known_methods=' apt go github_release uv pipx npm cargo git git_venv docker official_archive wget_mirror runtime manual '
known_tags=' core runtime recon web api mobile code cloud wordlists ai '
known_categories=' core runtime recon proxy discovery vuln api js-secrets sast-sca android ios reversing wordlists cloud container ai '

# Unique names.
dupes=$(catalog_tool_names | sort | uniq -d)
[[ -z "$dupes" ]] || bad "duplicate tool name(s): $(tr '\n' ' ' <<<"$dupes")"

# One pass: name, tags, method, desc, optin, apt-count, go, repo, pypi, npm,
# crate, git, url, dest, runtime.
while IFS=$'\t' read -r name tags method desc optin naptn go repo pypi npm crate git url dest runtime category gui asset image; do
  [[ -z "$name" ]] && continue
  [[ -n "$desc" ]] || bad "$name: missing desc"
  ((${#desc} <= 48)) || bad "$name: desc is ${#desc} chars (>48): $desc"
  [[ -n "$tags" ]] || bad "$name: missing tags"
  [[ "$known_methods" == *" $method "* ]] || bad "$name: unknown method '$method'"
  [[ "$category" != - ]] || bad "$name: missing category"
  [[ "$known_categories" == *" $category "* ]] || bad "$name: unknown category '$category'"
  [[ "$gui" == true || "$gui" == false ]] || bad "$name: gui must be true/false"

  IFS=',' read -ra _tg <<< "$tags"
  for t in "${_tg[@]}"; do [[ "$known_tags" == *" $t "* ]] || bad "$name: unknown tag '$t'"; done

  case "$method" in
    apt)            ((naptn > 0))        || bad "$name: apt method needs non-empty 'apt'" ;;
    go)             [[ -n "$go" ]]       || bad "$name: go method needs 'go'" ;;
    github_release) [[ "$repo" != - ]]  || bad "$name: github_release needs 'repo'" ;;
    pipx)           [[ "$pypi" != - ]]  || bad "$name: pipx needs 'pypi'" ;;
    npm)            [[ "$npm" != - ]]   || bad "$name: npm needs 'npm'" ;;
    cargo)          [[ "$crate" != - ]] || bad "$name: cargo needs 'crate'" ;;
    git)            [[ "$git" != - && "$dest" != - ]] || bad "$name: git needs 'git' and 'dest'" ;;
    wget_mirror)    [[ "$url" != - && "$dest" != - ]] || bad "$name: wget_mirror needs 'url' and 'dest'" ;;
    runtime)        [[ "$runtime" != - ]] || bad "$name: runtime needs 'runtime'" ;;
    git_venv)       [[ "$git" != - && "$dest" != - ]] || bad "$name: git_venv needs 'git' and 'dest'" ;;
    docker)         [[ "$image" != - ]] || bad "$name: docker needs 'image'" ;;
    official_archive) [[ ( "$repo" != - && "$asset" != - ) || "$url" != - ]] || bad "$name: official_archive needs repo+asset or url" ;;
    uv)             [[ "$pypi" != - ]]   || bad "$name: uv needs 'pypi'" ;;
  esac
# Default optional fields to "-" so no column is ever empty: with a tab IFS,
# empty fields would otherwise collapse and shift every later column.
done < <("$YQ" '.tools[] | [
    .name, (.tags | join(",")), .method, .desc, (.opt_in // false),
    ((.apt // []) | length), (.go // "-"), (.repo // "-"), (.pypi // "-"),
    (.npm // "-"), (.crate // "-"), (.git // "-"),
    (if (.url | type) == "!!str" then .url elif (.url | type) == "!!map" then "map" else "-" end), (.dest // "-"),
    (.runtime // "-"), (.category // "-"), (.gui // false),
    (if (.asset | type) == "!!str" then .asset elif (.asset | type) == "!!map" then "map" else "-" end),
    (.image // "-")] | @tsv' "$TOOLS_YAML")

# Profiles reference only known tags.
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    [[ "$known_tags" == *" $t "* ]] || bad "profile $p: unknown tag '$t'"
  done < <(catalog_profile_tags "$p")
done < <(catalog_profiles)

# Binary pins (github_release/official_archive) must also carry a checksum.
# Package pins (uv/pipx) name an exact PyPI version and are verified by uv/pip.
while IFS= read -r t; do
  [[ -z "$t" ]] && continue
  if [[ -z "$(catalog_tool_field "$t" sha256)" && -z "$(catalog_tool_field "$t" checksum_file)" ]]; then
    bad "$t: pinned (has version) but no sha256/checksum_file"
  fi
done < <("$YQ" '.tools[] | select(.version != null and (.method == "github_release" or .method == "official_archive")) | .name' "$TOOLS_YAML")

# Package pins are only meaningful for the Python methods that honour them.
while IFS= read -r t; do
  [[ -z "$t" ]] && continue
  bad "$t: version is only honoured by github_release, official_archive, uv and pipx"
done < <("$YQ" '.tools[] | select(.version != null and (.method != "github_release" and .method != "official_archive" and .method != "uv" and .method != "pipx")) | .name' "$TOOLS_YAML")

if ((fail)); then echo "catalog validation FAILED" >&2; exit 1; fi
echo "catalog validation passed ($(catalog_tool_names | wc -l | tr -d ' ') tools)"
