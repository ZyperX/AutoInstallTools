#!/usr/bin/env bash
# shellcheck disable=SC2154  # BIN_DIR from lib/common.sh
# docker: pull an image and drop a wrapper in ~/.local/bin that runs it.
# Never uses --privileged.
# Catalog keys: image (required), docker_args (optional extra `docker run` args), bin.

install_docker_tool() (
  local name=$1 image args bin
  image=$(catalog_tool_field "$name" image)
  args=$(catalog_tool_field "$name" docker_args)
  bin=$(catalog_tool_bin "$name")
  [[ -n "$image" ]] || { record_failure "$name" 'docker method needs image'; return 0; }

  command -v "$bin" >/dev/null 2>&1 && { ok "$name already installed; skipping"; return 0; }
  if dryrun; then would "docker pull $image and wrapper $BIN_DIR/$bin"; return 0; fi
  command -v docker >/dev/null || { record_failure "$name" 'docker is required'; return 0; }

  retry docker pull "$image" || { record_failure "$name" 'docker pull failed'; return 0; }
  cat > "$BIN_DIR/$bin" <<EOF
#!/usr/bin/env bash
exec docker run --rm -it $args "$image" "\$@"
EOF
  chmod 0755 "$BIN_DIR/$bin"
  manifest_add "$name" docker "$image" "$BIN_DIR/$bin"
  ok "Installed $name (docker: $image)"
)
