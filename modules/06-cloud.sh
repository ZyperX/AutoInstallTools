#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/github.sh"
[[ "$PROFILE" != full ]] && return 0
log 'Installing cloud and Kubernetes clients'
# apt awscli was dropped in Ubuntu 24.04; install AWS CLI v2 from AWS's
# official zip into user space (B6). GPG signature verification is a Phase 2 TODO.
install_awscli_v2() {
  command -v aws >/dev/null 2>&1 && { ok 'aws already installed; skipping'; return 0; }
  if dryrun; then would 'install AWS CLI v2 from awscli.amazonaws.com'; return 0; fi
  command -v curl >/dev/null && command -v unzip >/dev/null || { record_failure 'awscli' 'curl and unzip are required'; return 0; }
  local tmp; tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' RETURN
  retry curl -fL --retry 3 -o "$tmp/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" \
    || { record_failure 'awscli' 'download failed'; return 0; }
  unzip -q "$tmp/awscliv2.zip" -d "$tmp" || { record_failure 'awscli' 'could not unzip installer'; return 0; }
  "$tmp/aws/install" --bin-dir "$BIN_DIR" --install-dir "$HOME/.local/aws-cli" --update \
    || { record_failure 'awscli' 'installer failed'; return 0; }
  ok 'Installed AWS CLI v2'
}
install_awscli_v2
for repo in derailed/k9s ahmetb/kubectx; do github_install_latest "$repo" || true; done
warn 'Azure CLI, Google Cloud CLI, Helm and kubectl require vendor repositories; see README for opt-in commands.'
