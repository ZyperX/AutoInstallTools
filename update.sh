#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/apt.sh
source "$ROOT/lib/apt.sh"     # apt_update_all lives here (B3)
# shellcheck source=lib/github.sh
source "$ROOT/lib/github.sh"
init_paths; acquire_lock; trap release_lock EXIT

log 'Updating apt packages'; apt_update_all

if command -v go >/dev/null; then
  go install github.com/projectdiscovery/pdtm/cmd/pdtm@latest || true
  [[ -x "$HOME/go/bin/pdtm" ]] && ln -sf "$HOME/go/bin/pdtm" "$BIN_DIR/pdtm"
fi
# Keep the ProjectDiscovery tools and nuclei templates current (B9).
command -v pdtm >/dev/null && { pdtm -ua || true; }
command -v nuclei >/dev/null && { nuclei -update-templates || true; }

command -v pipx >/dev/null && { pipx upgrade-all || true; }
command -v npm >/dev/null && { npm update -g || true; }
command -v cargo >/dev/null && { cargo install-update -a || true; }

FORCE_INSTALL=1
export FORCE_INSTALL
for repo in "${GITHUB_UPDATABLE[@]}"; do github_install_latest "$repo" || warn "Could not update $repo"; done

for repo in SecLists PayloadsAllTheThings FuzzDB OneListForAll; do
  [[ -d "$WORDLISTS/$repo/.git" ]] && { git -C "$WORDLISTS/$repo" pull --ff-only || true; }
done
# Refresh the Assetnote CDN mirror (timestamping fetches only changed lists).
if [[ -d "$WORDLISTS/assetnote/data" ]] && command -v wget >/dev/null; then
  wget -r --no-parent -R 'index.html*' -e robots=off -nH -N -P "$WORDLISTS/assetnote" \
    https://wordlists-cdn.assetnote.io/data/ || true
fi
log 'Update completed.'
