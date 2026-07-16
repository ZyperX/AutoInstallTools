#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"
init_paths
missing=0
while IFS='|' read -r name profile required; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  case "$profile" in minimal) ;; full|mobile) ;; *) continue;; esac
  if command -v "$name" >/dev/null 2>&1; then ok "$name: $(command -v "$name")";
  elif [[ "$required" == required ]]; then err "$name: missing"; missing=1;
  else warn "$name: optional/missing"; fi
done < "$ROOT/config/tools.conf"
[[ -d "$WORDLISTS" ]] && ok "Wordlist directory: $WORDLISTS" || warn "Wordlist directory missing"
((missing)) && exit 1 || log "Doctor: baseline checks passed."
