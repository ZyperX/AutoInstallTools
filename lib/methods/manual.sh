#!/usr/bin/env bash
# manual: no automated install. Print the tool's notes and record it as manual
# so `ait doctor` knows it is expected but unmanaged.
install_manual() {
  local name=$1 notes
  notes=$(catalog_tool_field "$name" notes)
  if dryrun; then would "print manual install instructions for $name"; return 0; fi
  warn "$name must be installed manually."
  [[ -n "$notes" ]] && log "  $notes"
  manifest_add "$name" manual - -
}
