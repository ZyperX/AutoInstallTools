# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Release-readiness hardening

#### Fixed
- Binary release installers now require a pinned SHA-256/checksum and reject
  missing, malformed, unavailable, or mismatched verification data.
- Failed tool installs now produce a non-zero command result after all requested
  tools have been attempted, so CI can report real failures.
- Catalog TSV rows preserve empty platform and Homebrew fields. This fixes
  profile resolution, menu selection, and WSL GUI launcher discovery.
- `ait install`, `ait update`, and `ait uninstall --dry-run` no longer create
  persistent user state; added CLI-level dry-run coverage.
- Apt refreshes its package index once per install and retries failed batches
  package by package.
- Temurin JDK 21 now installs in user space with the API-provided SHA-256,
  including on Debian 12 and Ubuntu 22.04 where `openjdk-21-jdk` is absent.
- Mirrored WSL networking now refuses Windows builds below 22621; the Windows
  companion applies the same minimum and keeps Ghidra versions side by side.

#### Added
- CI install matrix for web/mobile on Ubuntu 22.04/24.04, Debian 12, and Kali;
  install failures are no longer swallowed.
- Weekly catalog pin update workflow, contribution/security/troubleshooting
  docs, and explicit per-architecture checksum schema checks.
- Apt method tests, checksum fail-closed tests, and CLI dry-run tests.

### Phase 5 — WSL & Windows

#### Added
- `ait wsl-net status|mirrored|nat|toggle`: WSL2-only `networkingMode` editor
  that backs up `.wslconfig`, touches only `[wsl2]`, preserves comments/other
  keys and CRLF, compares configured vs live mode and reports restart-pending.
  `--dry-run` prints the diff and changes nothing.
- Main-menu WSL entry now shows `WSL networking: Mirrored [ON|OFF]` with a
  restart-pending hint.
- `.desktop` launchers for installed GUI tools (`~/.local/share/applications`),
  which WSLg exposes in the Windows Start menu; removed again on uninstall.
- Richer `ait doctor` WSL checks (WSLg + `DISPLAY`/`WAYLAND_DISPLAY`, wsl-net
  configured mode).
- `windows/ait-windows.ps1`: Out-GridView/numbered checklist for winget tools
  plus Caido/Ghidra/rust_ASC downloads, and `-WslNetwork Mirrored|Nat` with the
  same backup/CRLF rules. PSScriptAnalyzer job added to CI.
- `docs/wsl.md` covering WSLg, mirrored networking, adb/USB, Frida, proxy CA
  and the Windows companion.
- Bats fixtures for `.wslconfig`: missing file, no `[wsl2]`, existing key, other
  keys, CRLF, dry-run, toggle and restart-pending status.

### Phase 4 — Mobile helpers

#### Added
- `ait frida-server [--device SERIAL]`: reads the host Frida version and device
  ABI, downloads the matching release, verifies its GitHub API sha256, pushes it
  to `/data/local/tmp`, starts it (via `su` when available) and confirms with
  `frida-ps`. `--dry-run` touches neither the network nor the device.
- `ait proxy-ca --burp|--caido|--mitmproxy [CERT]`: normalises PEM/DER to
  `<subject_hash_old>.0` and prints user- and system-store steps, including the
  Android 14+ APEX `conscrypt` cacerts path and a persistence warning.
- `ait doctor` now reports per-device adb state and, on WSL, usbipd / wireless /
  `ADB_SERVER_SOCKET` hints plus the port-5037 warning.
- Pin `frida-tools` 14.13.0 and `objection` 1.12.5 in the catalog; `uv`/`pipx`
  now honour a catalog `version` (exact PyPI pin) and validate it.
- Bats tests for ABI mapping, PEM/DER CA naming and the frida-server dry run.

### Phase 3 — Interactive menu

#### Added
- `./ait` (and `ait menu`) opens the interactive menu: Mobile, Web, All,
  Update existing, and the WSL networking entry on WSL.
- Mobile/Web submenus offer Install all or Select tools; the checklist shows each
  tool's description, category, installed marker and opt-in state, with GUI tools
  unticked and marked "(recommended on Windows)" on WSL.
- `whiptail` UI sized from the terminal, with a numbered text fallback that
  accepts `1,3,5-9` and offers to install `whiptail`.
- `ait list --category NAME` (and category in `--json`).
- Bats tests for the text fallback, row metadata and menu → profile mapping.

### Phase 2E — Console-script git_venv tools

#### Fixed
- `git_venv` installs the cloned project when it has no root script (ghauri's
  `setup.py` console entry point), instead of looking for a non-existent `*.py`.

### Phase 2D — CI-discovered installer fixes

#### Fixed
- `official_archive` reads per-platform `sha256` maps by key instead of passing
  the whole YAML map to the verifier (Caido, jadx, apktool, Opengrep).
- `github_release` accepts versioned binaries containing dots
  (`ipatool-2.7.0-linux-amd64`), then falls back to any executable.
- `hermes-dec` now exposes its real `hbc-decompiler` entry point.
- `ghauri` is installed from Git (not available on PyPI).
- Removed `jq`/`grep` pipelines into `head` that could fail via SIGPIPE under
  `pipefail`.

### Phase 2C — Catalog completion

#### Added
- The full curated catalog from the spec: Caido CLI/desktop, ZAP, Burp (manual),
  GraphQL tooling, CodeQL/Opengrep/Semgrep, sourcemapper, Hurl, Medusa, bagbak,
  Grapefruit, a resolver list, `whiptail`, `httpie` and `uro`.
- Per-platform `asset`/`url` maps for `official_archive`, so vendor downloads
  (Caido, CodeQL, Opengrep, Google platform-tools) pick the right arch.
- `scripts/pin.sh` now records per-arch assets and checksums from GitHub asset
  digests, upstream checksum files, or by hashing the asset when neither exists.
  Most release tools are pinned and verified as a result.

#### Changed
- Profiles match the spec: `full` is now `all`, `web` includes API + code tools,
  and `vps` never selects GUI tools.
- Python tools use the `uv` method (pipx fallback), matching the spec.
- The resolver filters by platform, orders runtimes/apt-deps first, and errors
  with a suggested name on an unknown `--with`/`--without` value.
- Google's upstream `platform-tools` and the official `apktool` jar replace apt.

### Phase 1 — Catalog engine

Adds the declarative catalog and the `ait` CLI. Install methods, checksum
pinning and manifest-based uninstall are formalised in Phase 2.

#### Added
- `ait` CLI: `list`, `install` (catalog-driven, honours `--profile`/`--with`/
  `--without`/`--dry-run`/`--yes`), and wrappers for `doctor`/`update`/`uninstall`.
- `catalog/tools.yaml` (70 tools ported from the modules) and
  `catalog/profiles.yaml` (`minimal`/`web`/`api`/`mobile`/`code`/`vps`/`full`/`ai`).
- `lib/catalog.sh`: bootstraps a pinned, sha256-verified `yq` and resolves
  profiles/tags; `lib/dispatch.sh` maps each catalog method to its installer.
- Tests: `tests/validate-catalog.sh` (schema: required fields, ≤48-char
  descriptions, known methods/tags, unique names) and `tests/resolver.sh`
  (profile selection, `--with`/`--without` by name and tag, opt-in exclusion).

#### Fixed
- `read`/TSV parsing: optional columns are kept non-empty so the tab IFS cannot
  collapse adjacent empty fields and shift columns.
- `install_go_toolchain`/`install_rust_toolchain`/`install_awscli_v2` are now
  subshell functions so their tmp-cleanup `trap` cannot leak to later returns.
- Catalog membership checks capture output before `grep -q` to avoid a pipefail
  SIGPIPE false negative.

### Phase 0 — Hygiene

Fixes the bugs catalogued as B1–B13 in [`PLAN.md`](PLAN.md) and adds basic repo
infrastructure. No `ait` CLI or catalog yet — that is Phase 1.

#### Fixed
- **Arjun** is installed with `pipx` (it is a Python tool), not `go install` (B1).
- **Go and Rust** now come from upstream — the official Go tarball (verified
  against go.dev's published sha256) and rustup via a checksum-verified
  `rustup-init` — instead of apt's too-old packages; `GOTOOLCHAIN=auto` is set (B2).
- **`update.sh`** sources `lib/apt.sh` so `apt_update_all` exists (B3).
- **`--dry-run`** is now truthful: every installer short-circuits before touching
  the system or the network, and the dry-run smoke test proves nothing is installed (B4).
- **GitHub release matcher** recognises `x86_64`/`aarch64`/`64bit` asset names,
  skips `.deb`/`.rpm`/`.sbom`/`.sig`/checksum/other-OS files, prefers archives
  over raw binaries, and verifies sha256 when upstream publishes it (B5).
- Replaced broken/absent apt packages with upstream methods: mikefarah **yq**,
  **eza**, **feroxbuster**, **AWS CLI v2**, and the Docker **compose v2** plugin (B6).
- **naabu** now gets `libpcap-dev`; **amass** installs from its v5 release binary
  instead of the stale `/v4` `go install` path (B7).
- Profiles are distinct again: `minimal` = core + runtimes, `mobile` = + mobile,
  `full` = everything (B8).
- **`update.sh`** runs `pdtm -ua` and `nuclei -update-templates`, and tracks
  `eza` instead of the archived `exa` (B9).
- **Aliases** no longer shadow `cat`/`find` with broken definitions (B10) and are
  copied to `~/.local/share/ait` so a moved clone does not break your shell (B11).
- **`doctor.sh`** actually runs each tool's check command rather than only
  testing for its presence (B12).

#### Added
- Assetnote wordlists mirror (CDN, timestamped) in the wordlists module and `update.sh`.
- `LICENSE` (MIT), `.editorconfig`, `.shellcheckrc`, `Makefile` (`lint`, `test`),
  GitHub Actions CI (shellcheck + dry-run test), and a dry-run smoke test (B13).
- A target `README.md` with a project-status banner marking not-yet-built features.
