#!/usr/bin/env bash
# AutoInstallTools: Linux/Ubuntu + WSL AppSec workstation provisioning.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

PROFILE=full; DRY_RUN=0; NO_SHELL=0
usage() { cat <<'EOF'
Usage: ./install.sh [--minimal|--full|--mobile] [--dry-run] [--no-shell]
Installs only tools you are authorized to use. Safe to re-run.
EOF
}
while (($#)); do case "$1" in
  --minimal) PROFILE=minimal;; --full) PROFILE=full;; --mobile) PROFILE=mobile;;
  --dry-run) DRY_RUN=1;; --no-shell) NO_SHELL=1;; -h|--help) usage; exit 0;;
  *) die "Unknown option: $1";; esac; shift; done
export PROFILE DRY_RUN
require_linux; init_paths; acquire_lock
trap release_lock EXIT
begin_failure_report
log "AutoInstallTools profile: $PROFILE"
confirm_or_exit

for module in "$ROOT"/modules/*.sh; do
  # shellcheck disable=SC1090
  source "$module" || record_failure "${module##*/}" 'module returned an error'
done

if (( ! NO_SHELL )); then configure_shell; fi
log "Installation completed. Run ./doctor.sh to review the environment."
report_failures
