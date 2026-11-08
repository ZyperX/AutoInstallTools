#!/usr/bin/env bash
# shellcheck disable=SC2154  # BOOTSTRAP_HOME/ROOT from the entrypoint
# VPS profile tuning: a tmux config for long runs and a raised open-file limit.
# All changes are idempotent and reversible (`ait uninstall --all`).

_tune_append_block() { # <file> <start-marker> <end-marker> <body>
  local file=$1 start=$2 end=$3 body=$4
  [[ -f "$file" ]] || : > "$file"
  grep -qF -- "$start" "$file" 2>/dev/null && return 0
  printf '\n%s\n%s\n%s\n' "$start" "$body" "$end" >> "$file"
}

_tune_remove_block() { # <file> <start-marker> <end-marker>
  local file=$1
  [[ -f "$file" ]] || return 0
  sed_inplace "/$2/,/$3/d" "$file"
}

# vps_tune: called automatically for `ait install --profile vps`.
vps_tune() {
  local dest="$BOOTSTRAP_HOME/tmux.conf" rc="$HOME/.bashrc"
  [[ "${SHELL:-}" == *zsh ]] && rc="$HOME/.zshrc"

  if dryrun; then
    would "install config/tmux.conf to $dest and source it from $HOME/.tmux.conf"
    would "raise the open-file limit (ulimit -n 65535; /etc/security/limits.d with sudo)"
    return 0
  fi

  mkdir -p "$BOOTSTRAP_HOME"
  if [[ -f "$ROOT/config/tmux.conf" ]]; then
    install -m 0644 "$ROOT/config/tmux.conf" "$dest"
    _tune_append_block "$HOME/.tmux.conf" \
      '# >>> AIT tmux >>>' '# <<< AIT tmux <<<' \
      "if-shell \"test -f $dest\" \"source-file $dest\""
    ok "tmux config: $HOME/.tmux.conf sources $dest"
  fi

  _tune_append_block "$rc" '# >>> AIT limits >>>' '# <<< AIT limits <<<' \
    'ulimit -n 65535 2>/dev/null || true'
  ok "open-file limit raised in new shells ($rc)"

  # System-wide limits need root; only do it when sudo is already usable so the
  # installer never blocks on a password prompt in CI or a non-interactive run.
  local limits=/etc/security/limits.d/99-ait.conf
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    if printf '* soft nofile 65535\n* hard nofile 65535\n' | sudo -n tee "$limits" >/dev/null 2>&1; then
      ok "system limits: $limits"
    else
      warn "could not write $limits; per-shell ulimit still applies"
    fi
  else
    warn 'skipping /etc/security/limits.d (sudo needs a password); per-shell ulimit is set'
  fi
}

# vps_untune: remove the blocks and files vps_tune created.
vps_untune() {
  if dryrun; then would 'remove the AIT tmux/limits blocks'; return 0; fi
  local f
  for f in "$HOME/.tmux.conf" "$HOME/.bashrc" "$HOME/.zshrc"; do
    _tune_remove_block "$f" '# >>> AIT tmux >>>' '# <<< AIT tmux <<<'
    _tune_remove_block "$f" '# >>> AIT limits >>>' '# <<< AIT limits <<<'
  done
  rm -f -- "$BOOTSTRAP_HOME/tmux.conf"
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo -n rm -f /etc/security/limits.d/99-ait.conf 2>/dev/null || true
  fi
}
