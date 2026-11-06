#!/usr/bin/env bash
# Prove that `./install.sh --dry-run` changes nothing: no binaries land in the
# user bin dir and the run only logs intended actions (B4 / definition of done).
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

tmp="$(mktemp -d)"; trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"; mkdir -p "$HOME"
export BIN_DIR="$HOME/.local/bin"
export BOOTSTRAP_HOME="$HOME/.local/share/ait"
export WORDLISTS="$HOME/Wordlists"
export CI=true   # skip the interactive confirmation

log="$tmp/out.log"
if ! "$ROOT/install.sh" --full --dry-run --no-shell >"$log" 2>&1; then
  echo "FAIL: install.sh --dry-run exited non-zero"; cat "$log"; exit 1
fi

# 1. No executables were installed into the user bin directory.
placed="$(find "$BIN_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$placed" != 0 ]]; then
  echo "FAIL: --dry-run placed $placed file(s) in $BIN_DIR"; find "$BIN_DIR" -type f; exit 1
fi

# 2. The run actually announced dry-run actions.
if ! grep -q '\[dry-run\]' "$log"; then
  echo "FAIL: no [dry-run] markers in output"; cat "$log"; exit 1
fi

# 3. No real package/runtime manager was invoked (only announced).
if grep -Eq 'Installed (Go|rustup|AWS|Node)' "$log"; then
  echo "FAIL: a real installation ran during --dry-run"; cat "$log"; exit 1
fi

echo "PASS: --dry-run installed nothing and only logged intended actions"
