#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
init_paths
missing=0

# Verify each tool: if a check command is given, actually run it (so a broken
# or half-installed binary is caught, not just a name on PATH); otherwise fall
# back to a presence check (B12). The check string is split into an argv array
# and executed directly — never eval'd on catalog data.
while IFS='|' read -r name profile required check; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  case "$profile" in minimal | full | mobile) ;; *) continue ;; esac

  if ! command -v "$name" >/dev/null 2>&1; then
    if [[ "$required" == required ]]; then err "$name: missing"; missing=1
    else warn "$name: optional/missing"; fi
    continue
  fi

  if [[ -z "${check// /}" ]]; then
    ok "$name: $(command -v "$name")"
    continue
  fi

  read -ra cmd <<< "$check"
  if out=$("${cmd[@]}" 2>&1); then
    ok "$name: $(printf '%s\n' "$out" | head -n1)"
  else
    warn "$name: present at $(command -v "$name") but '$check' did not run cleanly"
  fi
done < "$ROOT/config/tools.conf"

if [[ -d "$WORDLISTS" ]]; then ok "Wordlist directory: $WORDLISTS"; else warn 'Wordlist directory missing'; fi
case ":$PATH:" in
  *":$BIN_DIR:"*) ok "PATH includes $BIN_DIR" ;;
  *) warn "$BIN_DIR is not on PATH; open a new shell or source your rc" ;;
esac
is_wsl && warn 'WSL detected: USB device passthrough (adb/frida) needs usbipd-win on the Windows side.'

if ((missing)); then exit 1; else log 'Doctor: baseline checks passed.'; fi
