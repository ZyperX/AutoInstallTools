#!/usr/bin/env bash
[[ "$PROFILE" == minimal ]] && return 0
log 'Synchronizing public wordlists'
declare -A repos=([SecLists]=https://github.com/danielmiessler/SecLists.git [PayloadsAllTheThings]=https://github.com/swisskyrepo/PayloadsAllTheThings.git [FuzzDB]=https://github.com/fuzzdb-project/fuzzdb.git [OneListForAll]=https://github.com/six2dez/OneListForAll.git)
for name in "${!repos[@]}"; do
  if [[ -d "$WORDLISTS/$name/.git" ]]; then ok "$name already present; skipping (use ./update.sh to refresh it)"
  else retry git clone --depth 1 "${repos[$name]}" "$WORDLISTS/$name" || record_failure "$name" 'wordlist clone failed'; fi
done
