#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/github.sh"
[[ "$PROFILE" != full ]] && return 0
log 'Installing container analysis utilities'
apt_install docker.io
# The compose v2 plugin lives in Docker's own repo, not stock apt; install the
# release binary as a Docker CLI plugin in user space (B6).
github_install_latest docker/compose docker-compose "$HOME/.docker/cli-plugins/docker-compose" || true
for repo in jesseduffield/lazydocker wagoodman/dive aquasecurity/trivy anchore/syft anchore/grype; do
  github_install_latest "$repo" || true
done
# shellcheck disable=SC2016  # $USER is meant to appear literally for the user to run
warn 'Add your user to the docker group manually if desired: sudo usermod -aG docker $USER (then sign out/in).'
