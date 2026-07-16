#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"
init_paths
cat <<EOF
This removes only bootstrap-managed user files:
  $BIN_DIR, $STATE_DIR, and shell snippets tagged PENTEST-BOOTSTRAP.
It deliberately does not remove apt packages, language runtimes, Docker, or $WORDLISTS.
EOF
read -r -p 'Type REMOVE to continue: ' answer
[[ "$answer" == REMOVE ]] || { log 'Cancelled.'; exit 0; }
rm -rf -- "$BIN_DIR" "$STATE_DIR"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f "$rc" ]] && sed -i '/# >>> PENTEST-BOOTSTRAP >>>/,/# <<< PENTEST-BOOTSTRAP <<</d' "$rc"
done
log 'Managed files removed.'
