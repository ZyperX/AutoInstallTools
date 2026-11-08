#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR/DRY_RUN from lib/common.sh
# .desktop launchers for GUI tools. WSLg exposes ~/.local/share/applications
# in the Windows Start menu, so these become normal Windows shortcuts.

AIT_DESKTOP_DIR="${AIT_DESKTOP_DIR:-$HOME/.local/share/applications}"

_desktop_is_wsl() { is_wsl || [[ ${AIT_WSL:-0} == 1 ]]; }

_desktop_category() {
  case "$1" in
    proxy) echo 'Network;' ;;
    android | reversing) echo 'Development;' ;;
    *) echo 'Utility;' ;;
  esac
}

# desktop_launcher_write <tool> <bin> <desc> <category>
desktop_launcher_write() {
  local tool=$1 bin=$2 desc=$3 category=$4 exec file
  exec="$BIN_DIR/$bin"
  file="$AIT_DESKTOP_DIR/ait-$tool.desktop"
  if dryrun; then would "write $file for $exec"; return 0; fi
  mkdir -p "$AIT_DESKTOP_DIR"
  cat > "$file" <<EOF
[Desktop Entry]
Type=Application
Name=$tool
Comment=$desc
Exec="$exec" %U
Terminal=false
Categories=$(_desktop_category "$category")
StartupNotify=true
EOF
  chmod 0644 "$file"
}

desktop_launcher_remove() {
  local tool=$1 file="$AIT_DESKTOP_DIR/ait-$1.desktop"
  dryrun && { would "remove $file"; return 0; }
  rm -f -- "$file"
}

# Write launchers for every installed GUI tool; no-op outside WSL.
desktop_launchers_refresh() {
  _desktop_is_wsl || return 0
  if dryrun; then
    would "write .desktop launchers for installed GUI tools in $AIT_DESKTOP_DIR"
    return 0
  fi
  local name cat gui bin desc
  while IFS=$'\t' read -r name _ _ cat gui _ _ _ _ bin desc _ _; do
    [[ -z "$name" || "$gui" != true ]] && continue
    [[ -x "$BIN_DIR/$bin" ]] || continue
    desktop_launcher_write "$name" "$bin" "$desc" "$cat"
  done < <(catalog_resolve_tsv)
}
