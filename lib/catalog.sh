#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT/BOOTSTRAP_HOME provided by the entrypoint
# Catalog engine: bootstrap a pinned yq, read catalog/*.yaml, resolve profiles.

CATALOG_DIR="${CATALOG_DIR:-$ROOT/catalog}"
TOOLS_YAML="$CATALOG_DIR/tools.yaml"
PROFILES_YAML="$CATALOG_DIR/profiles.yaml"

# Pinned yq so the catalog parses identically on any distro (sha256 from the
# GitHub release asset digests). Bump both version and hashes together.
YQ_VERSION='v4.54.2'
YQ_SHA256_amd64='44c7759059b4910827a0059a2757b22001e59360cdecdb2ef8dedc4b6c7e9f32'
YQ_SHA256_arm64='bd44211dcd29a5f0eb701d4b7eb5ccd0cfff3bd3966cb4f7f9bd5b13701d997e'
YQ=''

# Ensure $YQ points at a mikefarah yq v4. Prefer an existing one, else download
# the pinned binary (verified) into the AIT bin dir.
bootstrap_yq() {
  local ait_bin="$BOOTSTRAP_HOME/bin"
  if [[ -x "$ait_bin/yq" ]] && "$ait_bin/yq" --version 2>/dev/null | grep -qi mikefarah; then
    YQ="$ait_bin/yq"; return 0
  fi
  if command -v yq >/dev/null 2>&1 && yq --version 2>/dev/null | grep -qi mikefarah; then
    YQ="$(command -v yq)"; return 0
  fi
  command -v curl >/dev/null || die 'curl is required to bootstrap yq'

  local arch sha
  case "$(uname -m)" in
    x86_64) arch=amd64; sha="$YQ_SHA256_amd64" ;;
    aarch64 | arm64) arch=arm64; sha="$YQ_SHA256_arm64" ;;
    *) die "unsupported CPU architecture for yq: $(uname -m)" ;;
  esac

  local tmp; tmp=$(mktemp -d)
  log "Bootstrapping yq $YQ_VERSION"
  retry curl -fL --retry 3 -o "$tmp/yq" \
    "https://github.com/mikefarah/yq/releases/download/$YQ_VERSION/yq_linux_$arch" \
    || { rm -rf -- "$tmp"; die 'could not download yq'; }
  if ! echo "$sha  $tmp/yq" | sha256sum -c - >/dev/null 2>&1; then
    rm -rf -- "$tmp"; die 'yq checksum verification failed'
  fi
  install -D -m 0755 "$tmp/yq" "$ait_bin/yq"
  rm -rf -- "$tmp"
  YQ="$ait_bin/yq"
}

# q <yq-expression> <file> : run the bootstrapped yq.
q() { [[ -n "$YQ" ]] || bootstrap_yq; "$YQ" "$1" "$2"; }

# --- profiles ---
catalog_profiles() { q '.profiles | keys | .[]' "$PROFILES_YAML"; }
# Capture first, then grep: piping yq straight into `grep -q` trips pipefail via
# SIGPIPE and reports failure even on a match.
catalog_profile_exists() { local p; p=$(catalog_profiles); grep -qx "$1" <<<"$p"; }
catalog_profile_tags() { q ".profiles.$1 // [] | .[]" "$PROFILES_YAML"; }

# --- tools ---
# One line per tool: name <TAB> tags(csv) <TAB> method <TAB> desc <TAB> opt_in
# <TAB> bin <TAB> category. Every column is always non-empty, so IFS=$'\t'
# read never collapses tabs.
catalog_tools_tsv() {
  q '.tools[] | [.name, (.tags | join(",")), .method, .desc, (.opt_in // false), (.bin // .name), .category] | @tsv' "$TOOLS_YAML"
}
catalog_tool_names() { q '.tools[].name' "$TOOLS_YAML"; }
catalog_categories() { q '[.tools[].category] | unique | .[]' "$TOOLS_YAML"; }
catalog_tool_exists() { local n; n=$(catalog_tool_names); grep -qx "$1" <<<"$n"; }
# field of a single tool (empty string if absent/null)
catalog_tool_field() {
  local out; out=$(q ".tools[] | select(.name == \"$1\") | .$2 // \"\"" "$TOOLS_YAML" 2>/dev/null || true)
  [[ "$out" == null ]] && out=''
  printf '%s' "$out"
}

# Like catalog_tool_field, but returns nothing for mappings (per-platform maps
# are read with catalog_tool_field "field.$plat_key" instead).
catalog_tool_str() {
  local out; out=$(catalog_tool_field "$1" "$2")
  [[ "$out" == *$'\n'* || "$out" =~ ^[a-z0-9_]+:\ [^[:space:]] ]] && out=''
  printf '%s' "$out"
}
# a tool's bin (defaults to its name)
catalog_tool_bin() {
  local b; b=$(catalog_tool_field "$1" bin)
  [[ -n "$b" ]] && printf '%s' "$b" || printf '%s' "$1"
}

# csv-of-tags intersects a space-separated tag list?
_tags_intersect() {
  local have=",$1," want
  for want in $2; do [[ "$have" == *",$want,"* ]] && return 0; done
  return 1
}

# All tags used by the catalog (for validating --with/--without).
catalog_tags() { q '[.tools[].tags[]] | unique | .[]' "$TOOLS_YAML"; }

# Resolver rows: name tags opt_in category gui platforms priority.
# Priority 0 = runtimes, 1 = tools that need apt deps, 2 = everything else,
# so a deterministic install order puts prerequisites first.
catalog_resolve_tsv() {
  q '.tools[] | [
    .name,
    (.tags | join(",")),
    (.opt_in // false),
    .category,
    (.gui // false),
    ((.platforms // ["linux", "wsl"]) | join(",")),
    (if .category == "runtime" then 0
     elif ((.apt_deps // []) | length) > 0 then 1
     else 2 end),
    .method,
    (if ((.apt_deps // []) | length) > 0 then "1" else "0" end),
    (.bin // .name),
    .desc
  ] | @tsv' "$TOOLS_YAML"
}

_platform_allowed() {
  local have=",$1,"; [[ "$have" == *",$2,"* ]]
}

# Offer close matches for a typo'd tool/tag name.
_catalog_suggest() {
  local needle=$1 candidates out
  candidates=$( { catalog_tool_names; catalog_tags; } | sort -u )
  out=$(grep -i -- "${needle:0:3}" <<<"$candidates" | head -n3 | paste -sd, -)
  [[ -n "$out" ]] || out=$(head -n3 <<<"$candidates" | paste -sd, -)
  printf '%s' "$out"
}

_is_known_selector() {
  local item=$1 names
  names=$( { catalog_tool_names; catalog_tags; } )
  grep -qx -- "$item" <<<"$names"
}

_require_selector() {
  _is_known_selector "$1" \
    || die "Unknown tool or tag: '$1' (did you mean: $(_catalog_suggest "$1")?)"
}

# resolve_tools <profile> <with_csv> <without_csv> -> tool names, one per line
resolve_tools() {
  local profile=$1 with=${2:-} without=${3:-}
  local tags platform tsv
  tags=$(catalog_profile_tags "$profile" | tr '\n' ' ')
  platform=$(detect_platform)
  tsv=$(catalog_resolve_tsv)

  declare -A sel=() prio_of=() cat_of=()
  local name tagcsv optin category gui platforms prio item
  # Read every column: with fewer variables, the last one swallows the rest of
  # the line (including tabs), which corrupts the sort key.
  while IFS=$'\t' read -r name tagcsv optin category gui platforms prio _ _ _ _; do
    [[ -z "$name" ]] && continue
    prio_of[$name]=$prio; cat_of[$name]=$category
    [[ "$optin" == true ]] && continue
    _tags_intersect "$tagcsv" "$tags" || continue
    _platform_allowed "$platforms" "$platform" || continue
    [[ "$profile" == vps && "$gui" == true ]] && continue
    sel[$name]=1
  done <<< "$tsv"

  # --with: a tool name adds that tool; anything else is treated as a tag.
  IFS=',' read -ra _w <<< "$with"
  for item in "${_w[@]}"; do
    [[ -z "$item" ]] && continue
    _require_selector "$item"
    if grep -qx -- "$item" <<<"$(cut -f1 <<<"$tsv")"; then
      sel[$item]=1
    else
      while IFS=$'\t' read -r name tagcsv _ _ _ platforms _ _ _ _ _; do
        [[ -z "$name" ]] && continue
        _tags_intersect "$tagcsv" "$item" || continue
        _platform_allowed "$platforms" "$platform" || continue
        sel[$name]=1
      done <<< "$tsv"
    fi
  done

  # --without: remove by tool name or by tag.
  IFS=',' read -ra _wo <<< "$without"
  for item in "${_wo[@]}"; do
    [[ -z "$item" ]] && continue
    _require_selector "$item"
    if grep -qx -- "$item" <<<"$(cut -f1 <<<"$tsv")"; then
      unset "sel[$item]"
    else
      while IFS=$'\t' read -r name tagcsv _ _ _ _ _; do
        [[ -z "$name" ]] && continue
        _tags_intersect "$tagcsv" "$item" && unset "sel[$name]"
      done <<< "$tsv"
    fi
  done

  local n
  for n in "${!sel[@]}"; do
    printf '%s\t%s\t%s\n' "${prio_of[$n]}" "${cat_of[$n]}" "$n"
  done | sort -t$'\t' -k1,1n -k2,2 -k3,3 | cut -f3
}
