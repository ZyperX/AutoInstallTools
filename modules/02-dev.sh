#!/usr/bin/env bash
source "$ROOT/lib/apt.sh"; source "$ROOT/lib/pipx.sh"; source "$ROOT/lib/npm.sh"; source "$ROOT/lib/node.sh"
log 'Installing development runtimes and tooling'
apt_install python3 python3-pip pipx openjdk-21-jdk maven gradle golang-go rustc cargo
install_node_lts
pipx ensurepath --force || true
npm_install pnpm @anthropic-ai/claude-code opencode-ai || true
pipx_install aider-chat || true
pipx_install llm || true
pipx_install shell-gpt || true
