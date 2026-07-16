#!/usr/bin/env bash
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/github.sh"
[[ "$PROFILE" == minimal ]] && return 0
log 'Installing cloud and Kubernetes clients'
apt_install awscli
for repo in derailed/k9s ahmetb/kubectx; do github_install_latest "$repo" || true; done
warn 'Azure CLI, Google Cloud CLI, Helm and kubectl require vendor repositories; see README for opt-in commands.'
