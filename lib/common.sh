#!/usr/bin/env bash
set -Eeuo pipefail
BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-$HOME/.local/share/pentest-bootstrap}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
STATE_DIR="$BOOTSTRAP_HOME/state"; WORDLISTS="${WORDLISTS:-$HOME/Wordlists}"
export PATH="$BIN_DIR:$HOME/go/bin:$PATH"
log(){ printf '\033[1;34m[+]\033[0m %s\n' "$*"; }; ok(){ printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }; err(){ printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }
die(){ err "$*"; exit 1; }
run(){ if (( ${DRY_RUN:-0} )); then log "[dry-run] $*"; else "$@"; fi; }
retry(){ local n=0; until "$@"; do ((n++)); ((n>=3)) && return 1; warn "Retry $n/3: $*"; sleep $((n*2)); done; }
init_paths(){ mkdir -p "$BIN_DIR" "$STATE_DIR" "$WORDLISTS"; }
begin_failure_report(){ FAILURES_FILE="$STATE_DIR/failed-tools"; export FAILURES_FILE; : > "$FAILURES_FILE"; }
record_failure(){
  local tool=$1 detail=${2:-installation failed}
  [[ -n ${FAILURES_FILE:-} ]] || return 0
  if ! grep -Fqx "$tool" "$FAILURES_FILE" 2>/dev/null; then printf '%s\n' "$tool" >> "$FAILURES_FILE"; fi
  warn "$tool: $detail (continuing)"
}
report_failures(){
  [[ -s ${FAILURES_FILE:-/dev/null} ]] || { ok 'All requested tool installers completed successfully.'; return 0; }
  err 'The following tools could not be installed:'
  while IFS= read -r tool; do printf '  - %s\n' "$tool" >&2; done < "$FAILURES_FILE"
  warn "Review the preceding error output, fix prerequisites, then rerun ./install.sh."
}
require_linux(){ [[ "$(uname -s)" == Linux ]] || die 'This bootstrap currently supports Linux/WSL only.'; command -v sudo >/dev/null || die 'sudo is required.'; }
is_wsl(){ grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }
acquire_lock(){ exec 9>"$STATE_DIR/install.lock"; flock -n 9 || die 'Another bootstrap process is running.'; }
release_lock(){ flock -u 9 || true; }
confirm_or_exit(){ [[ -t 0 && ${CI:-} != true ]] || return 0; read -r -p "Continue with $PROFILE installation? [y/N] " a; [[ "$a" =~ ^[Yy]$ ]] || exit 0; }
configure_shell(){ local rc="$HOME/.bashrc"; [[ "${SHELL:-}" == *zsh ]] && rc="$HOME/.zshrc"; grep -q 'PENTEST-BOOTSTRAP' "$rc" 2>/dev/null || cat >> "$rc" <<EOF
# >>> PENTEST-BOOTSTRAP >>>
export PATH="$BIN_DIR:\$HOME/go/bin:\$PATH"
[ -f "$ROOT/config/aliases.sh" ] && source "$ROOT/config/aliases.sh"
# <<< PENTEST-BOOTSTRAP <<<
EOF
}
