#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/github.sh"; source "$ROOT/lib/awscli.sh"
[[ "$PROFILE" != full ]] && return 0
log 'Installing cloud and Kubernetes clients'
install_awscli_v2
for repo in derailed/k9s ahmetb/kubectx; do github_install_latest "$repo" || true; done
warn 'Azure CLI, Google Cloud CLI, Helm and kubectl require vendor repositories; see README for opt-in commands.'
