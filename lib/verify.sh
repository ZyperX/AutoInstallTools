#!/usr/bin/env bash
# sha256 verification helpers (Linux and macOS).

# verify_sha256 <file> <expected-hex> : true if the file matches.
verify_sha256() {
  local file=$1 expected=$2 actual
  [[ -n "$expected" ]] || return 2
  actual=$(sha256_of "$file")
  [[ "$actual" == "$expected" ]]
}

# checksum_from_file <checksum-file> <asset-name> : print the expected hash for
# an asset listed in a checksums file (lines "<hash>  <name>"), or empty.
checksum_from_file() {
  local cfile=$1 name=$2
  # index() is a literal match (asset names contain dots/dashes, not regexes).
  awk -v n="$name" '$2 == n || $2 == ("*" n) { print $1; exit }' "$cfile" 2>/dev/null
}
