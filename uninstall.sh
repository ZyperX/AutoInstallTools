#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
init_paths
cat <<EOF
This removes only bootstrap-managed user files:
  $BIN_DIR, $BOOTSTRAP_HOME, and shell snippets tagged AIT.
It deliberately does not remove apt packages, language runtimes, Docker, or $WORDLISTS.
EOF
read -r -p 'Type REMOVE to continue: ' answer
[[ "$answer" == REMOVE ]] || { log 'Cancelled.'; exit 0; }
rm -rf -- "$BIN_DIR" "$BOOTSTRAP_HOME"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f "$rc" ]] && sed -i '/# >>> AIT >>>/,/# <<< AIT <<</d' "$rc"
done
log 'Managed files removed.'
