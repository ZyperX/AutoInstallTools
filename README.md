# Pentest Bootstrap

Opinionated Linux/Ubuntu and WSL provisioning for authorized AppSec, web, cloud, Android and source-review work. It is deliberately idempotent and uses `~/.local/bin`, `~/go/bin`, `~/Wordlists`, and `~/.local/share/pentest-bootstrap` rather than writing into the repository.

## Quick start

```bash
git clone <your-repository-url> pentest-bootstrap
cd pentest-bootstrap
chmod +x install.sh update.sh doctor.sh uninstall.sh
./install.sh --full
./doctor.sh
```

Profiles: `--minimal` installs foundations; `--full` adds the broad web/cloud/recon stack; `--mobile` includes full plus Android/mobile dependencies. Use `--dry-run` to inspect shell commands, and `--no-shell` to avoid changing shell startup files.

Node.js 22 LTS is provisioned from NodeSource because current CLI tools such as Claude Code require Node 22+, while many Ubuntu releases package Node 18. npm global tools are installed under `~/.local`, never with `sudo npm`.

## Scope and platform notes

- This is Linux/Ubuntu-first. It detects WSL but does not configure USB passthrough.
- iOS tooling requires macOS, Xcode, signing context, and often a jailbroken/test device; it is documented as a manual follow-up rather than pretending Linux can fully provision it.
- Burp Suite is commercial/GUI software and is intentionally not downloaded automatically. Install it from the vendor and configure its JDK separately.
- Vendor-repository clients (Azure CLI, Google Cloud CLI, Helm, kubectl) are left opt-in because their repository keys and distribution support change frequently. Follow the official vendor documentation after reviewing it.
- GitHub releases are selected through the official API. Where a project uses nonstandard asset names or needs signatures, the installer reports a warning rather than guessing.

## Safety model

Run tools only against systems you own or are explicitly authorized to assess. The bootstrap stores no credentials, tokens, targets, or scan configuration. Review packages and upstream releases before use; release binary installation is inherently a supply-chain decision.

## Lifecycle

`./update.sh` updates apt, language-managed tools, compatible GitHub releases, and cloned wordlists. `./doctor.sh` reports baseline command availability. `./uninstall.sh` removes only bootstrap-managed user files; it intentionally never removes apt packages, runtimes, Docker, or wordlists.

Installers continue after an individual tool fails. At completion, `install.sh` prints a deduplicated list of unsuccessful tools and saves it at `~/.local/share/pentest-bootstrap/state/failed-tools`; resolve prerequisites and rerun the installer to retry them.

Before installing, the bootstrap checks the package database and relevant executable or package-manager inventory. Existing tools are skipped; use `./update.sh` when you want managed release binaries and wordlists refreshed.

The `config/` directory contains auditable baseline package, Git, tmux, alias, and zsh snippets. Only the PATH/alias shell snippet is changed automatically; copy the other configuration files into place if you want them.

## Extending

Add a tool to the appropriate module using the smallest appropriate installer: `apt_install`, `go_install`, `pipx_install`, `npm_install`, `cargo_install`, or `github_install_latest`. Keep a manual path for tools that have unclear licensing, OS dependence, or unverified artifact conventions.
# AutoInstallTools
