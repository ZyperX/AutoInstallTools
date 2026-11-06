#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/golang.sh"; source "$ROOT/lib/github.sh"
[[ "$PROFILE" != full ]] && return 0
log 'Installing reconnaissance tools'
# naabu builds against libpcap; without the headers its go install fails (B7).
apt_install libpcap-dev
for spec in \
 'github.com/projectdiscovery/subfinder/v2/cmd/subfinder:subfinder' \
 'github.com/projectdiscovery/httpx/cmd/httpx:httpx' \
 'github.com/projectdiscovery/nuclei/v3/cmd/nuclei:nuclei' \
 'github.com/projectdiscovery/katana/cmd/katana:katana' \
 'github.com/projectdiscovery/dnsx/cmd/dnsx:dnsx' \
 'github.com/projectdiscovery/naabu/v2/cmd/naabu:naabu' \
 'github.com/projectdiscovery/uncover/cmd/uncover:uncover' \
 'github.com/projectdiscovery/alterx/cmd/alterx:alterx' \
 'github.com/projectdiscovery/shuffledns/cmd/shuffledns:shuffledns' \
 'github.com/projectdiscovery/mapcidr/cmd/mapcidr:mapcidr' \
 'github.com/tomnomnom/assetfinder:assetfinder' \
 'github.com/tomnomnom/waybackurls:waybackurls' \
 'github.com/lc/gau/v2/cmd/gau:gau' \
 'github.com/hakluke/hakrawler:hakrawler'; do
  IFS=: read -r pkg bin <<< "$spec"; go_install "$pkg" "$bin" || true
done
# amass: the /v4 module path resolves to a stale tag, so use the v5 release
# binary instead of go install (B7).
github_install_latest owasp-amass/amass amass || true
