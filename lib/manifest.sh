#!/usr/bin/env bash
# shellcheck disable=SC2154  # BOOTSTRAP_HOME/STATE_DIR provided by lib/common.sh
# Install manifest: records exactly what ait installed so uninstall can remove
# only those things. One TSV row per tool:
#   tool <TAB> method <TAB> version <TAB> paths(comma) <TAB> installed_at(iso)
# Field access uses awk, not `grep -P`: BSD grep on macOS has no PCRE.

manifest_file() { printf '%s\n' "$STATE_DIR/manifest.tsv"; }

manifest_init() { mkdir -p "$STATE_DIR"; [[ -f "$(manifest_file)" ]] || : > "$(manifest_file)"; }

# manifest_add <tool> <method> <version> <paths-comma-separated>
manifest_add() {
  local tool=$1 method=$2 version=${3:-} paths=${4:-} mf
  mf=$(manifest_file); mkdir -p "$STATE_DIR"
  # Replace any existing row for this tool (idempotent re-install).
  if [[ -f "$mf" ]]; then
    local tmp; tmp=$(mktemp)
    awk -F'\t' -v t="$tool" 'BEGIN { OFS = "\t" } $1 != t' "$mf" > "$tmp" || true
    mv "$tmp" "$mf"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$tool" "$method" "${version:--}" "${paths:--}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$mf"
}

manifest_has() {
  local mf; mf=$(manifest_file)
  [[ -f "$mf" ]] || return 1
  awk -F'\t' -v t="$1" '$1 == t { found = 1 } END { exit !found }' "$mf"
}
manifest_tools() { local mf; mf=$(manifest_file); if [[ -f "$mf" ]]; then cut -f1 "$mf"; fi; }
manifest_row() {
  local mf; mf=$(manifest_file); [[ -f "$mf" ]] || return 0
  awk -F'\t' -v t="$1" '$1 == t { print; exit }' "$mf"
}
manifest_field() { # <tool> <1-based col>
  manifest_row "$1" | cut -f"$2"
}
manifest_remove_row() {
  local tool=$1 mf tmp; mf=$(manifest_file); [[ -f "$mf" ]] || return 0
  tmp=$(mktemp)
  awk -F'\t' -v t="$tool" 'BEGIN { OFS = "\t" } $1 != t' "$mf" > "$tmp" || true
  mv "$tmp" "$mf"
}
