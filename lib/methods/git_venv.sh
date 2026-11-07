#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR from lib/common.sh
# git_venv: clone a Python tool, give it an isolated venv, and drop a wrapper in
# ~/.local/bin that runs its entrypoint from that venv.
#
# Catalog keys: git (clone URL), dest (clone dir), bin (wrapper name).
# Convention: the repo's entrypoint is <bin>.py at the repo root; if a
# requirements.txt is present it is installed into the venv.

install_git_venv() (
  local name=$1 url dest bin
  url=$(catalog_tool_field "$name" git)
  dest=$(_expand_path "$(catalog_tool_field "$name" dest)")
  bin=$(catalog_tool_bin "$name")
  [[ -n "$url" && -n "$dest" ]] || { record_failure "$name" 'git_venv needs git and dest'; return 0; }

  command -v "$bin" >/dev/null 2>&1 && { ok "$name already installed; skipping"; return 0; }
  if dryrun; then would "git_venv $name: clone $url, venv, wrapper $BIN_DIR/$bin"; return 0; fi
  command -v git >/dev/null || { record_failure "$name" 'git required'; return 0; }
  command -v python3 >/dev/null || { record_failure "$name" 'python3 required'; return 0; }

  if [[ -d "$dest/.git" ]]; then git -C "$dest" pull --ff-only || true
  else retry git clone --depth 1 "$url" "$dest" || { record_failure "$name" 'clone failed'; return 0; }
  fi

  python3 -m venv "$dest/.venv" || { record_failure "$name" 'venv creation failed'; return 0; }
  "$dest/.venv/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1 || true
  if [[ -f "$dest/requirements.txt" ]]; then
    "$dest/.venv/bin/pip" install --quiet -r "$dest/requirements.txt" || { record_failure "$name" 'pip install failed'; return 0; }
  fi

  # Entry point: catalog `entry` wins, else <bin>.py, else a same-named .py,
  # else the venv's console script.
  local entry='' declared
  declared=$(catalog_tool_field "$name" entry)
  if [[ -n "$declared" ]]; then
    [[ -f "$dest/$declared" ]] && entry="$dest/$declared"
  else
    for cand in "$bin.py" "${bin//-/_}.py" "$name.py"; do
      [[ -f "$dest/$cand" ]] && { entry="$dest/$cand"; break; }
    done
  fi
  if [[ -n "$entry" ]]; then
    cat > "$BIN_DIR/$bin" <<EOF
#!/usr/bin/env bash
exec "$dest/.venv/bin/python" "$entry" "\$@"
EOF
  elif [[ -x "$dest/.venv/bin/$bin" ]]; then
    cat > "$BIN_DIR/$bin" <<EOF
#!/usr/bin/env bash
exec "$dest/.venv/bin/$bin" "\$@"
EOF
  else
    record_failure "$name" "no entry point ($bin.py or console script) found"; return 0
  fi
  chmod 0755 "$BIN_DIR/$bin"
  manifest_add "$name" git_venv - "$dest,$BIN_DIR/$bin"
  ok "Installed $name"
)
