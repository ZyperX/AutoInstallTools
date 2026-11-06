#!/usr/bin/env bash
# shellcheck disable=SC2154  # ROOT, PROFILE, BIN_DIR, WORDLISTS are set by install.sh
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/pipx.sh"; source "$ROOT/lib/npm.sh"
source "$ROOT/lib/node.sh"; source "$ROOT/lib/golang.sh"; source "$ROOT/lib/cargo.sh"
log 'Installing development runtimes and tooling'
# Go and Rust come from upstream, not apt: apt ships versions too old to build
# current security tooling (B2). Python tools use pipx for now (uv in Phase 2).
apt_install python3 python3-pip pipx openjdk-21-jdk maven gradle
install_go_toolchain
install_rust_toolchain
install_node_lts
if ! dryrun; then pipx ensurepath --force || true; fi
npm_install pnpm @anthropic-ai/claude-code opencode-ai || true
pipx_install aider-chat || true
pipx_install llm || true
pipx_install shell-gpt || true
