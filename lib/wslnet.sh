#!/usr/bin/env bash
# shellcheck disable=SC2154  # DRY_RUN from lib/common.sh
# WSL networking toggle: change only networkingMode under [wsl2] in .wslconfig,
# with a backup, CRLF-safe editing and a live/config comparison.

is_wsl2() {
  [[ ${AIT_WSL2:-0} == 1 ]] && return 0
  grep -qi 'microsoft-standard' /proc/sys/kernel/osrelease 2>/dev/null
}

# wsl_net_require_wsl: hard requirement for the CLI (tests set WSL_CONFIG).
wsl_net_require_wsl() {
  is_wsl2 && return 0
  [[ -n ${WSL_CONFIG:-} ]] && return 0
  die 'ait wsl-net only runs inside WSL2 (Windows 10 22H2+ / Windows 11).'
}

# Locate %UserProfile%\.wslconfig from WSL; fall back to ~/.wslconfig.
wsl_net_config_path() {
  if [[ -n ${WSL_CONFIG:-} ]]; then printf '%s\n' "$WSL_CONFIG"; return 0; fi
  local win='' path=''
  if command -v cmd.exe >/dev/null 2>&1; then
    win=$(cmd.exe /c echo '%UserProfile%' 2>/dev/null | tr -d '\r')
    if [[ -n "$win" ]] && command -v wslpath >/dev/null 2>&1; then
      path=$(wslpath -u "$win" 2>/dev/null || true)
    fi
  fi
  [[ -n "$path" ]] || path=$HOME
  printf '%s\n' "$path/.wslconfig"
}

# Configured mode: prints mirrored, nat, or empty when the file/key is absent.
wsl_net_read_mode() {
  local cfg; cfg=$(wsl_net_config_path)
  [[ -f "$cfg" ]] || return 0
  awk '
    { line=$0; sub(/\r$/, "", line) }
    line ~ /^[[:space:]]*\[wsl2\][[:space:]]*$/ { inw=1; next }
    line ~ /^[[:space:]]*\[/ { inw=0; next }
    inw && line ~ /^[[:space:]]*networkingMode[[:space:]]*=/ {
      sub(/^[^=]*=[[:space:]]*/, "", line); print line; exit
    }' "$cfg"
}

# Live mode from the running distro: mirrored when Windows and WSL share an IP.
wsl_net_live_mode() {
  if [[ -n ${AIT_WSL_LIVE_MODE:-} ]]; then printf '%s\n' "$AIT_WSL_LIVE_MODE"; return 0; fi
  if ! command -v ipconfig.exe >/dev/null 2>&1 || ! command -v ip >/dev/null 2>&1; then
    printf 'unknown\n'; return 0
  fi
  local win wsl common
  win=$(ipconfig.exe 2>/dev/null | tr -d '\r' \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | grep -vE '^(0\.0\.0\.0|127\.|169\.254\.|255\.)' | sort -u)
  wsl=$(ip -4 -o addr show 2>/dev/null | awk '{ print $4 }' | cut -d/ -f1 | sort -u)
  if [[ -z "$win" || -z "$wsl" ]]; then printf 'unknown\n'; return 0; fi
  common=$(comm -12 <(printf '%s\n' "$win") <(printf '%s\n' "$wsl") | head -n1)
  if [[ -n "$common" ]]; then printf 'mirrored\n'; else printf 'nat\n'; fi
}

wsl_net_menu_label() {
  local mode live label
  mode=$(wsl_net_read_mode); mode=${mode:-nat}
  live=$(wsl_net_live_mode)
  if [[ "$mode" == mirrored ]]; then label='WSL networking: Mirrored [ON]'; else label='WSL networking: Mirrored [OFF]'; fi
  [[ "$live" != unknown && "$live" != "$mode" ]] && label+=' (restart pending)'
  printf '%s\n' "$label"
}

wsl_net_status() {
  local cfg mode live
  cfg=$(wsl_net_config_path)
  mode=$(wsl_net_read_mode); mode=${mode:-nat}
  live=$(wsl_net_live_mode)
  printf 'Config:    %s\n' "$cfg"
  if [[ -f "$cfg" ]]; then
    printf 'Configured: %s\n' "$mode"
  else
    printf 'Configured: %s (Windows default; no .wslconfig)\n' "$mode"
  fi
  printf 'Live:       %s\n' "$live"
  if [[ "$live" != unknown && "$live" != "$mode" ]]; then
    printf 'Status:     restart pending (wsl --shutdown)\n'
  elif [[ "$live" == unknown ]]; then
    printf 'Status:     live mode could not be detected\n'
  else
    printf 'Status:     in sync\n'
  fi
  printf '\nNotes:\n'
  printf '  - The same port cannot be bound on both Windows and WSL.\n'
  printf '  - Windows/Hyper-V firewall may still block inbound connections.\n'
  printf '  - hostAddressLoopback=true is optional; mirrored mode already shares localhost.\n'
}

# _wsl_net_render <mode> <cfg>: print the new file to stdout, preserving lines.
_wsl_net_render() {
  local mode=$1 cfg=$2 cr=''
  [[ -f "$cfg" ]] && grep -qU $'\r' "$cfg" 2>/dev/null && cr=$'\r'
  if [[ ! -f "$cfg" ]]; then
    printf '[wsl2]\r\nnetworkingMode=%s\r\n' "$mode"
    return 0
  fi
  awk -v mode="$mode" -v cr="$cr" '
    { raw=$0; line=raw; sub(/\r$/, "", line) }
    line ~ /^[[:space:]]*\[wsl2\][[:space:]]*$/ { inw=1; print raw; next }
    line ~ /^[[:space:]]*\[/ {
      if (inw && !done) { print "networkingMode=" mode cr; done=1 }
      inw=0; print raw; next
    }
    inw && !done && line ~ /^[[:space:]]*networkingMode[[:space:]]*=/ {
      print "networkingMode=" mode cr; done=1; next
    }
    { print raw }
    END {
      if (!done) {
        if (!inw) { print "[wsl2]" cr }
        print "networkingMode=" mode cr
      }
    }' "$cfg"
}

_wsl_net_apply_hint() {
  printf '\nApply it with:  wsl.exe --shutdown\n'
  printf 'This closes every WSL terminal, including this one; reopen afterwards.\n'
  if [[ -t 0 && ${CI:-} != true ]]; then
    local a
    read -r -p 'Run wsl.exe --shutdown now? [y/N] ' a || return 0
    if [[ "$a" =~ ^[Yy]$ ]]; then
      if command -v wsl.exe >/dev/null 2>&1; then
        wsl.exe --shutdown && ok 'WSL is shutting down.'
      else
        warn 'wsl.exe is not available here; run it from PowerShell.'
      fi
    fi
  fi
}

# wsl_net_set <mirrored|nat>
wsl_net_set() {
  local mode=$1 cfg tmp backup
  case "$mode" in mirrored | nat) ;; *) die "Unknown mode: $mode (mirrored|nat)";; esac
  cfg=$(wsl_net_config_path)

  tmp=$(mktemp "$cfg.ait-XXXXXX") || die "Cannot write next to $cfg"
  _wsl_net_render "$mode" "$cfg" > "$tmp" || { rm -f -- "$tmp"; die 'Could not edit .wslconfig'; }

  if dryrun; then
    if [[ -f "$cfg" ]]; then
      diff -u --label "$cfg" --label "$cfg (proposed)" "$cfg" "$tmp" || true
    else
      printf '# new file: %s\n' "$cfg"; cat "$tmp"
    fi
    rm -f -- "$tmp"
    return 0
  fi

  if [[ -f "$cfg" ]]; then
    backup="$cfg.ait-backup-$(date -u +%Y%m%dT%H%M%SZ)"
    cp -p -- "$cfg" "$backup" || { rm -f -- "$tmp"; die "Could not back up $cfg"; }
    ok "Backed up to $backup"
  fi
  mv -- "$tmp" "$cfg" || die "Could not replace $cfg"
  ok "networkingMode=$mode written to $cfg"
  _wsl_net_apply_hint
}

wsl_net_toggle() {
  local mode; mode=$(wsl_net_read_mode); mode=${mode:-nat}
  if [[ "$mode" == mirrored ]]; then wsl_net_set nat; else wsl_net_set mirrored; fi
}

wsl_net_cli() {
  local cmd='' dry=0
  while (($#)); do case "$1" in
    status | mirrored | nat | toggle) cmd=$1; shift ;;
    --dry-run) dry=1; shift ;;
    -h | --help)
      cat <<'EOF'
Usage: ait wsl-net status|mirrored|nat|toggle [--dry-run]

Only WSL2. Edits networkingMode under [wsl2] in %UserProfile%\.wslconfig,
backs the file up first and preserves every other line and comment.
EOF
      return 0
      ;;
    *) die "Unknown option: $1 (try: ait wsl-net --help)" ;;
  esac; done
  [[ -n "$cmd" ]] || { die 'ait wsl-net needs status, mirrored, nat or toggle'; }
  wsl_net_require_wsl
  DRY_RUN=$dry; export DRY_RUN
  case "$cmd" in
    status) wsl_net_status ;;
    mirrored | nat) wsl_net_set "$cmd" ;;
    toggle) wsl_net_toggle ;;
  esac
}
