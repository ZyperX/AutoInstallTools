#!/usr/bin/env bash
# Generic latest-release installer. Projects with nonstandard assets are listed as optional.
GITHUB_UPDATABLE=("sharkdp/bat" "sharkdp/fd" "ogham/exa" "mikefarah/yq" "junegunn/fzf" "muesli/duf" "Byron/dua-cli" "jesseduffield/lazydocker" "wagoodman/dive" "aquasecurity/trivy" "anchore/syft" "anchore/grype" "derailed/k9s" "ahmetb/kubectx")
github_install_latest() (
  local repo=$1 api asset url tmp name arch; name=${repo##*/}; arch=$(uname -m)
  if [[ ${FORCE_INSTALL:-0} != 1 ]] && command -v "$name" >/dev/null 2>&1; then
    ok "$name already installed; skipping"
    return 0
  fi
  case "$arch" in x86_64) arch='amd64';; aarch64) arch='arm64';; esac
  command -v curl >/dev/null && command -v jq >/dev/null || { record_failure "$name" 'curl and jq are required for GitHub releases'; return 0; }
  api="https://api.github.com/repos/$repo/releases/latest"
  asset=$(retry curl -fsSL "$api" | jq -r --arg a "$arch" '.assets[] | select(.name|test($a;"i")) | select(.name|test("linux";"i")) | .browser_download_url' | head -n1) || { record_failure "$name" 'could not query the GitHub release API'; return 0; }
  [[ -n "$asset" && "$asset" != null ]] || { record_failure "$name" "no matching Linux $arch release asset"; return 0; }
  tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT; url="$asset"
  retry curl -fL --retry 3 --continue-at - -o "$tmp/asset" "$url" || { record_failure "$name" 'release download failed'; return 0; }
  case "$url" in *.tar.gz|*.tgz) tar -xzf "$tmp/asset" -C "$tmp";; *.zip) unzip -q "$tmp/asset" -d "$tmp";; *) cp "$tmp/asset" "$tmp/$name";; esac || { record_failure "$name" 'could not extract release archive'; return 0; }
  local bin; bin=$(find "$tmp" -type f \( -name "$name" -o -name "${name#*-}" \) | head -n1)
  [[ -n "$bin" ]] || { record_failure "$name" 'could not identify executable in release archive'; return 0; }
  install -m 0755 "$bin" "$BIN_DIR/$name" || { record_failure "$name" 'could not place executable in user bin directory'; return 0; }
  ok "Installed $name"
)
