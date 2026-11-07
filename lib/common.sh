#!/usr/bin/env bash
# Shared helpers: logging, dry-run, retry, locking, failure tracking, shell setup.
set -Eeuo pipefail

# All managed state and copied config live here so moving/deleting the clone
# never breaks an installed shell (see configure_shell / B11).
BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-$HOME/.local/share/ait}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
STATE_DIR="$BOOTSTRAP_HOME/state"
WORDLISTS="${WORDLISTS:-$HOME/Wordlists}"

# Runtimes install into user space; expose their bin dirs for this process.
export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"
export PATH="$BIN_DIR:$HOME/.local/go/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"

log()  { printf '\033[1;34m[+]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

# dryrun: true when --dry-run was passed. would: announce a skipped action.
dryrun() { (( ${DRY_RUN:-0} )); }
would()  { log "[dry-run] would $*"; }

# run wraps a single side-effecting command so --dry-run is truthful.
run() {
  if dryrun; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

retry() {
  local n=0
  until "$@"; do
    ((n++)); ((n >= 3)) && return 1
    warn "Retry $n/3: $*"
    sleep $((n * 2))
  done
}

init_paths() { mkdir -p "$BIN_DIR" "$STATE_DIR" "$WORDLISTS"; }

begin_failure_report() {
  FAILURES_FILE="$STATE_DIR/failed-tools"
  export FAILURES_FILE
  : > "$FAILURES_FILE"
}

record_failure() {
  local tool=$1 detail=${2:-installation failed}
  [[ -n ${FAILURES_FILE:-} ]] || return 0
  if ! grep -Fqx "$tool" "$FAILURES_FILE" 2>/dev/null; then
    printf '%s\n' "$tool" >> "$FAILURES_FILE"
  fi
  warn "$tool: $detail (continuing)"
}

report_failures() {
  [[ -s ${FAILURES_FILE:-/dev/null} ]] || {
    ok 'All requested tool installers completed successfully.'
    return 0
  }
  err 'The following tools could not be installed:'
  while IFS= read -r tool; do printf '  - %s\n' "$tool" >&2; done < "$FAILURES_FILE"
  local retry
  retry="$(paste -sd, - < "$FAILURES_FILE")"
  warn "Review the error output above, fix prerequisites, then retry with:"
  printf '    ./ait install --profile %s --with %s --yes\n' "${PROFILE:-web}" "$retry" >&2
}

require_linux() {
  [[ "$(uname -s)" == Linux ]] || die 'This bootstrap currently supports Linux/WSL only.'
  command -v sudo >/dev/null || die 'sudo is required.'
}

is_wsl() { grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }

# Platform names used by the catalog's `platforms` filter.
detect_platform() {
  case "$(uname -s)" in
    Linux) if is_wsl; then echo wsl; else echo linux; fi ;;
    Darwin) echo macos ;;
    *) echo unknown ;;
  esac
}

# Platform key for per-arch pinning maps (asset / sha256).
plat_key() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) echo linux_amd64 ;;
    Linux-aarch64 | Linux-arm64) echo linux_arm64 ;;
    Darwin-x86_64) echo darwin_amd64 ;;
    Darwin-arm64) echo darwin_arm64 ;;
    *) return 1 ;;
  esac
}

acquire_lock() {
  exec 9>"$STATE_DIR/install.lock"
  flock -n 9 || die 'Another bootstrap process is running.'
}
release_lock() { flock -u 9 || true; }

confirm_or_exit() {
  [[ -t 0 && ${CI:-} != true ]] || return 0
  read -r -p "Continue with $PROFILE installation? [y/N] " a
  [[ "$a" =~ ^[Yy]$ ]] || exit 0
}

# Add a PATH/aliases snippet to the user's shell rc. The snippet is copied into
# BOOTSTRAP_HOME so the rc keeps working if the clone is moved or removed.
configure_shell() {
  local rc="$HOME/.bashrc"
  [[ "${SHELL:-}" == *zsh ]] && rc="$HOME/.zshrc"
  local snippet="$BOOTSTRAP_HOME/shell.sh"

  if dryrun; then
    would "copy config/aliases.sh to $snippet and add an AIT block to $rc"
    return 0
  fi

  mkdir -p "$BOOTSTRAP_HOME"
  # shellcheck disable=SC2154  # ROOT is set by the entrypoint
  [[ -f "$ROOT/config/aliases.sh" ]] && install -m 0644 "$ROOT/config/aliases.sh" "$snippet"

  if grep -q '>>> AIT >>>' "$rc" 2>/dev/null; then
    ok "AIT shell block already present in $rc"
    return 0
  fi
  cat >> "$rc" <<EOF

# >>> AIT >>>
export PATH="$BIN_DIR:\$HOME/.local/go/bin:\$HOME/go/bin:\$HOME/.cargo/bin:\$PATH"
export GOTOOLCHAIN=auto
[ -f "$snippet" ] && . "$snippet"
# <<< AIT <<<
EOF
  ok "Added AIT shell block to $rc"
}
