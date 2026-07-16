#!/usr/bin/env bash
source "$ROOT/lib/golang.sh"
[[ "$PROFILE" == minimal ]] && return 0
log 'Installing reconnaissance tools'
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
 'github.com/hakluke/hakrawler:hakrawler' \
 'github.com/owasp-amass/amass/v4/...:amass'; do IFS=: read -r pkg bin <<< "$spec"; go_install "$pkg" "$bin" || true; done
