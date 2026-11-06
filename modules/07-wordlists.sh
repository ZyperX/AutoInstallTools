#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
[[ "$PROFILE" != full ]] && return 0
log 'Synchronizing public wordlists'
declare -A repos=([SecLists]=https://github.com/danielmiessler/SecLists.git [PayloadsAllTheThings]=https://github.com/swisskyrepo/PayloadsAllTheThings.git [FuzzDB]=https://github.com/fuzzdb-project/fuzzdb.git [OneListForAll]=https://github.com/six2dez/OneListForAll.git)
for name in "${!repos[@]}"; do
  if [[ -d "$WORDLISTS/$name/.git" ]]; then
    ok "$name already present; skipping (use ./update.sh to refresh it)"
  elif dryrun; then
    would "git clone ${repos[$name]} into $WORDLISTS/$name"
  else
    retry git clone --depth 1 "${repos[$name]}" "$WORDLISTS/$name" || record_failure "$name" 'wordlist clone failed'
  fi
done

# Assetnote wordlists are served from a CDN (not a git repo) and are several GB;
# mirror them with wget timestamping so re-runs only fetch what changed.
assetnote_dir="$WORDLISTS/assetnote"
if [[ -d "$assetnote_dir/data" ]]; then
  ok "assetnote already present; skipping (use ./update.sh to refresh it)"
elif dryrun; then
  would "mirror https://wordlists-cdn.assetnote.io/data/ into $assetnote_dir (several GB)"
elif ! command -v wget >/dev/null; then
  record_failure assetnote 'wget is required for the Assetnote wordlists'
else
  warn 'Downloading Assetnote wordlists (several GB); this can take a while.'
  wget -r --no-parent -R 'index.html*' -e robots=off -nH -N -P "$assetnote_dir" \
    https://wordlists-cdn.assetnote.io/data/ \
    || warn 'Assetnote mirror finished with some errors (partial lists possible).'
fi
