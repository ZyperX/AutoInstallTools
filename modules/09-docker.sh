#!/usr/bin/env bash
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/github.sh"
[[ "$PROFILE" == minimal ]] && return 0
log 'Installing container analysis utilities'
apt_install docker.io docker-compose-plugin || apt_install docker.io docker-compose
for repo in jesseduffield/lazydocker wagoodman/dive aquasecurity/trivy anchore/syft anchore/grype; do github_install_latest "$repo" || true; done
warn 'Add your user to the docker group manually if desired: sudo usermod -aG docker $USER (then sign out/in).'
