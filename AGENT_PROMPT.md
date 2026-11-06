# Prompt for the coding agent

> Put `README.md` and `PLAN.md` in the repo root (README as `README.target.md` until the work is done), then paste everything below the line into your agentic coder.

---

You are a senior DevSecOps engineer and Bash expert. You are improving **AutoInstallTools** (https://github.com/ZyperX/AutoInstallTools), a bootstrap that installs a complete web + mobile application-security pentesting toolkit on Linux (Ubuntu/Debian/Kali/WSL2), with macOS as a later beta.

## Goal
Turn the repo into a polished, trustworthy, GitHub-worthy project whose primary user is an AppSec pentester strong in **web and mobile (Android/iOS)** testing. One command should give them a correct, verified, up-to-date toolkit, and an easy way to keep it healthy.

## Inputs you must read first
1. The whole current repo (it's small: `install.sh`, `update.sh`, `doctor.sh`, `uninstall.sh`, `lib/`, `modules/`, `config/`).
2. `PLAN.md` — audit (bugs B1–B13), target architecture, phased roadmap, definition of done. **Follow it.**
3. `README.target.md` — the README describing the finished product. The tool catalog, profiles, commands and flags in it are the spec. When it and the code disagree at the end, fix one of them so they match.

## Working rules
- Work **phase by phase** as defined in `PLAN.md` §4. One branch + PR per phase, small focused commits, conventional commit messages. Don't start the next phase until CI is green.
- Before writing code for a phase, post a short plan (files to add/change, risks). After the phase, post a summary and what's left.
- **Verify every tool's install method against its upstream repo at implementation time** (release asset names per arch, checksum file name, binary name, Go module path, PyPI/npm name, current major version). Never guess asset names. If an upstream has no checksums, compute and pin the sha256 of the pinned version in the catalog and note it.
- If a tool in the README turns out to be archived, broken, or license-incompatible with automated install, don't force it: move it to `docs/not-included.md` with the reason, and tell me.
- Bash 5, `set -Euo pipefail`, shellcheck-clean (no blanket disables). Quote everything. No `eval` on catalog data. No `curl | bash` from third parties.
- Every side-effecting command goes through `run()` so `--dry-run` is truthful. Add a test proving dry-run modifies nothing (`$HOME`, `/usr`, package DB).
- `sudo` only for system packages and repo keys; announce before first use. Everything else in user space (`~/.local/bin`, `~/.local/share/ait`).
- Idempotent: second run must be a no-op apart from "already installed" lines. Failures are recorded and summarised; the run continues.
- Never store credentials, tokens, targets or scan data. Never auto-accept licenses (e.g. Burp) without an explicit `--with burp` and a prompt.
- Keep the code readable for contributors: small functions, comments only where intent isn't obvious, one install method per file.

## Deliverables (by end of all phases)
- `ait` CLI with `install | list | doctor | update | uninstall | frida-server | proxy-ca` and flags `--profile`, `--with`, `--without`, `--dry-run`, `--yes`, `--json` (doctor).
- **Interactive menu when `./ait` is run with no arguments** — this is the main way the user will use the tool, so build it exactly to `PLAN.md` §2a:
  - Main menu with exactly 4 options: *Install Mobile AppSec tools*, *Install Web AppSec tools*, *Install All tools*, *Update existing tools*.
  - Mobile or Web → submenu: *Install all* / *Select tools*.
  - *Select tools* → checklist with a short description right beside each tool name (from the catalog `description` field, ≤ 48 chars), `(installed)` marker, scrolling, category grouping, then a confirm summary.
  - *Update existing* updates only tools recorded in the install manifest (+ nuclei templates, wordlists).
  - `whiptail` first, numbered text-prompt fallback (`1,3,5-9` selection). Esc goes back a level.
  - Bats tests for the text fallback and for menu → profile mapping; the menu must reuse the same install functions as the flags.
- **WSL networking toggle** per `PLAN.md` §2b: `ait wsl-net status|mirrored|nat|toggle`, plus a 5th main-menu entry `WSL networking: Mirrored [ON|OFF]` shown only on WSL. Must back up `.wslconfig`, edit only `networkingMode` under `[wsl2]`, preserve everything else (CRLF-safe), check Windows build ≥ 22621, detect "restart pending", and never run `wsl --shutdown` without an explicit yes. Fixture-based bats tests required.
- **Windows companion** `windows/ait-windows.ps1` per `PLAN.md` §2c (winget installs for Burp, Caido, jadx, Ghidra, scrcpy, platform-tools; same networking toggle from the Windows side). Lint with PSScriptAnalyzer in CI.
- GUI apps on WSL: detect WSLg in `ait doctor`, install `.desktop` launchers for GUI tools (Caido, Burp, jadx-gui, Ghidra, scrcpy) so they show in the Windows Start menu, and document HiDPI scaling.
- `catalog/tools.yaml` + `catalog/profiles.yaml` holding every tool from the README, with schema validated in tests.
- Install methods: `apt`, `brew`, `github_release` (per-arch asset map + sha256), `go`, `uv` (pipx fallback), `npm`, `cargo`, `git_venv`, `docker`, `official_archive`, `manual`.
- Upstream runtimes: official Go tarball (+ `GOTOOLCHAIN=auto`), rustup, uv, Node 22 LTS, JDK 21.
- Mobile helpers: `frida-server` (detect host frida version + device ABI via `adb shell getprop ro.product.cpu.abi`, download matching release, verify, push to `/data/local/tmp`, start, check) and `proxy-ca` (convert Burp/Caido/mitmproxy CA to `<subject_hash_old>.0`, print install steps for user and system stores, including Android 14+ notes).
- `ait doctor`: runs each tool's `check` command, shows version/status table, warns on Frida host/device mismatch, detects WSL and usbipd/adb connectivity, stale nuclei templates, PATH problems.
- Manifest-based `ait uninstall` that removes only what was installed and the marked rc block.
- Tests: bats-core for catalog schema, profile resolution, dry-run, method functions (mock network/package managers), and an integration job that installs `--profile web` and `--profile mobile` (no device steps) in Docker for Ubuntu 22.04, 24.04, Debian 12 and Kali.
- CI: shellcheck, bats, integration matrix; weekly workflow that checks upstream releases and opens a PR bumping versions + checksums.
- Repo polish: MIT LICENSE, CONTRIBUTING.md (tool inclusion criteria, how to add a catalog entry), SECURITY.md, CHANGELOG.md, issue templates (bug, tool request), PR template, `docs/not-included.md`, `docs/wsl-mobile.md`, `docs/troubleshooting.md`, Makefile (`lint`, `test`, `integration`), and a terminal demo recording via `vhs` for the README.

## Adding new tools
The user will keep adding newer tools. First one to add: **Droid ASC** (https://github.com/MG1937/ASC) — fast on-demand APK search/decompiler.
- `droidasc`: PyPI package `droidasc`, Python ≥ 3.10, install with `uv tool install droidasc`; check: `droidasc -h`. Description: "Fast on-demand APK search & decompile".
- `rust_ASC` (https://github.com/MG1937/rust_ASC): the repo's release workflow builds assets named `rust_ASC-linux-x86_64`, `rust_ASC-linux-aarch64`, `rust_ASC-macos-aarch64` (and musl/Windows variants). Verify a release actually exists; if yes use `github_release` with sha256, else `cargo build --release --locked` from a pinned tag/commit. Install as `rust-asc`. Description: "Rust ASC: 10× faster, full APK decompile".
- Both tagged `mobile`, both Apache-2.0. Also add them to the Windows companion (`rust_ASC-windows-x86_64.exe`).

Make adding a tool a catalog-only change: one YAML entry with name, ≤48-char description, tags, method and check, no code edits. Never guess what an ambiguous tool name refers to; ask for the repo link.

## Start now
Begin with **Phase 0** from `PLAN.md`: fix bugs B1–B13 in the existing code, add LICENSE/Makefile/shellcheck CI, and give me the PR summary. Ask me only if a decision is irreversible or genuinely ambiguous; otherwise choose the sensible default and note it in the PR.
