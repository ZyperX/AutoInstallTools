#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/github.sh"
init_paths; acquire_lock; trap release_lock EXIT
log "Updating apt packages"; apt_update_all
command -v go >/dev/null && go install github.com/projectdiscovery/pdtm/cmd/pdtm@latest || true
command -v pipx >/dev/null && pipx upgrade-all || true
command -v npm >/dev/null && npm update -g || true
command -v cargo >/dev/null && cargo install-update -a || true
FORCE_INSTALL=1
export FORCE_INSTALL
for repo in "${GITHUB_UPDATABLE[@]}"; do github_install_latest "$repo" || warn "Could not update $repo"; done
for repo in SecLists PayloadsAllTheThings FuzzDB OneListForAll; do
  [[ -d "$WORDLISTS/$repo/.git" ]] && git -C "$WORDLISTS/$repo" pull --ff-only || true
done
log "Update completed."
