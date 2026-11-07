#!/usr/bin/env bash
# sha256 verification helpers.

# verify_sha256 <file> <expected-hex> : true if the file matches.
verify_sha256() {
  local file=$1 expected=$2 actual
  [[ -n "$expected" ]] || return 2
  actual=$(sha256sum "$file" | awk '{print $1}')
  [[ "$actual" == "$expected" ]]
}

# checksum_from_file <checksum-file> <asset-name> : print the expected hash for
# an asset listed in a checksums file (lines "<hash>  <name>"), or empty.
checksum_from_file() {
  local cfile=$1 name=$2
  # index() is a literal match (asset names contain dots/dashes, not regexes).
  awk -v n="$name" 'index($0, n) { print $1; exit }' "$cfile" 2>/dev/null
}
