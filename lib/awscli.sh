#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR provided by lib/common.sh
# AWS CLI v2 from AWS's official zip, into user space.
# apt awscli was dropped in Ubuntu 24.04; GPG signature verification is a Phase 2 TODO.
# Subshell function so the tmp-cleanup EXIT trap cannot leak to other returns.
install_awscli_v2() (
  command -v aws >/dev/null 2>&1 && { ok 'aws already installed; skipping'; return 0; }
  if dryrun; then would 'install AWS CLI v2 from awscli.amazonaws.com'; return 0; fi
  if ! { command -v curl >/dev/null && command -v unzip >/dev/null; }; then
    record_failure 'awscli' 'curl and unzip are required'; return 0
  fi
  local tmp; tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
  retry curl -fL --retry 3 -o "$tmp/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" \
    || { record_failure 'awscli' 'download failed'; return 0; }
  unzip -q "$tmp/awscliv2.zip" -d "$tmp" || { record_failure 'awscli' 'could not unzip installer'; return 0; }
  "$tmp/aws/install" --bin-dir "$BIN_DIR" --install-dir "$HOME/.local/aws-cli" --update \
    || { record_failure 'awscli' 'installer failed'; return 0; }
  ok 'Installed AWS CLI v2'
)
