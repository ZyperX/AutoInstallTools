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
  grep -F -- "$name" "$cfile" 2>/dev/null | awk '{print $1}' | head -n1
}
