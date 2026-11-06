# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
