# AutoInstallTools — Improvement Plan

Target: turn the current bootstrap (≈320 lines of Bash, 1 commit) into a polished, GitHub-worthy installer for web + mobile AppSec pentesters. The new `README.md` describes the target state; this plan is how to get there.

---

## 1. Audit of the current repo

### What's already good — keep it
- Modular layout (`lib/`, `modules/`, `config/`), idempotent "skip if present" checks.
- Failures are recorded and summarised instead of aborting the run.
- User-space installs (`~/.local/bin`, npm prefix in `~/.local`, no `sudo npm`).
- Lock file to prevent concurrent runs; WSL detection; honest notes on Burp/iOS.

### Bugs (fix first)

| # | Where | Problem |
|---|---|---|
| B1 | `modules/04-web.sh` | `go_install github.com/s0md3v/Arjun` — Arjun is a Python tool. Always fails. Install with `uv tool install arjun`. |
| B2 | `modules/02-dev.sh` | Go comes from apt. Ubuntu 22.04 ships Go 1.18; current ProjectDiscovery tools need a much newer Go, so most `go install`s fail there. Install the official Go tarball (or use mise) and set `GOTOOLCHAIN=auto`. Same issue for apt `rustc`/`cargo` → use rustup. |
| B3 | `update.sh` | Calls `apt_update_all` but never sources `lib/apt.sh` → `update.sh` dies on line 1 of work. |
| B4 | `install.sh` / `lib/common.sh` | `--dry-run` is parsed but `run()` is never used anywhere. **Dry-run actually installs everything.** |
| B5 | `lib/github.sh` | Asset match only tests `amd64`; many projects name assets `x86_64`/`64bit` (lazydocker, kubectx, trivy). `head -n1` can pick `.deb`, `.rpm`, `.sbom`, `.sig` or checksum files. No checksum verification at all. |
| B6 | `modules/01,04,05,06,09` | Several apt names don't exist on stock Ubuntu (some releases): `feroxbuster`, `jadx`, `dex2jar`, `awscli` (removed in 24.04), `docker-compose-plugin` (Docker's own repo), mikefarah `yq`. Apt `adb`/`apktool` are years old. |
| B7 | `modules/03-recon.sh` | `naabu` needs `libpcap-dev` → build fails without it. `amass` uses the stale v4 module path. |
| B8 | `modules/05-mobile.sh` | Runs for `--full` too, so `--full` and `--mobile` install the same thing — contradicts the README. |
| B9 | `update.sh` | Installs `pdtm` but never runs `pdtm -ua`; nuclei templates never update; `ogham/exa` is archived. |
| B10 | `config/aliases.sh` | `alias cat='batcat 2>/dev/null \|\| bat ... \|\| command cat'` passes arguments only to the last command → `cat file` breaks. `alias find='fd'` breaks scripts and muscle memory. |
| B11 | `lib/common.sh` | Shell rc sources `aliases.sh` from the clone path; moving/deleting the repo breaks every new shell. Copy it to `~/.local/share/ait/` instead. |
| B12 | `doctor.sh` | Checks 13 commands, only `command -v`. Doesn't verify tools actually run. |
| B13 | Repo | README has `<your-repository-url>` placeholders and two titles; no LICENSE, CI, tests, CONTRIBUTING, releases. |

---

## 2. Target architecture

```
AutoInstallTools/
├── ait                       # single entrypoint CLI (bash): install|list|doctor|update|uninstall|frida-server|proxy-ca
├── catalog/
│   ├── tools.yaml            # THE source of truth: every tool, method, version, checksum, tags, check
│   └── profiles.yaml         # profile -> tags/tools
├── lib/
│   ├── core.sh               # logging, run() wrapper (honours dry-run), retry, lock, state, OS/arch detect
│   ├── catalog.sh            # read catalog via bundled yq; resolve profile + --with/--without
│   ├── verify.sh             # sha256 verification, checksum-file parsing
│   └── methods/              # one file per install method
│       ├── apt.sh  brew.sh  github_release.sh  go.sh  uv.sh  npm.sh
│       ├── cargo.sh  git_venv.sh  docker.sh  official_archive.sh  manual.sh
├── helpers/
│   ├── frida-server.sh       # match host frida version + device ABI, push & start
│   └── proxy-ca.sh           # export Burp/Caido/mitmproxy CA as <subject_hash_old>.0
├── config/                   # tmux, zsh snippet, safe aliases (opt-in)
├── docs/                     # not-included.md, wsl-mobile.md, adding-tools.md, troubleshooting.md
├── tests/                    # bats tests: catalog schema, resolver, dry-run output, methods (mocked)
├── .github/
│   ├── workflows/ci.yml      # shellcheck + bats + install matrix (ubuntu 22.04/24.04, debian 12, kali) in containers
│   ├── workflows/bump.yml    # weekly: check upstream releases, open PR updating versions + checksums
│   ├── ISSUE_TEMPLATE/{bug.yml,tool-request.yml}
│   └── PULL_REQUEST_TEMPLATE.md
├── README.md  CONTRIBUTING.md  SECURITY.md  CHANGELOG.md  LICENSE  Makefile
```

### Key design decisions
1. **Declarative catalog** (`catalog/tools.yaml`). Modules stop hard-coding tools. One schema: `name, description, tags, method, repo|package|url, version, asset{os_arch: pattern}, sha256{os_arch} | checksum_file, bin, deps, check, platforms, notes, deprecated_by`.
2. **Bootstrap `yq`** (pinned + sha256) as the first step so the catalog can be parsed on any distro. Python 3.11 `tomllib` isn't available on 22.04, so YAML+yq is the portable choice.
3. **Runtimes from upstream:** official Go tarball, rustup, `uv` for Python tools (much faster than pipx, falls back to pipx), Node 22 LTS via NodeSource, Temurin/OpenJDK 21. Optionally let **mise** manage runtimes if present.
4. **Prefer release binaries over `go install`** for ProjectDiscovery and similar tools: no Go toolchain needed for most users, faster, verifiable. Keep `go install` only where no release exists.
5. **`run()` everywhere** — every side-effecting command goes through it so `--dry-run` is truthful (add a bats test that asserts dry-run changes nothing).
6. **Distro adapters:** `apt` on Ubuntu/Debian/Kali, `brew` on macOS; method files declare which platforms they support; catalog entries can skip platforms.
7. **State & uninstall manifest:** every installed file/dir recorded in `~/.local/share/ait/state/manifest.tsv`, so `ait uninstall` removes exactly what was installed.
8. **Interactive menu** when `./ait` runs with no arguments (spec in §2a). `--yes` and flags for CI/non-interactive use.

### 2a. Interactive menu spec

```
Main menu (whiptail --menu)
├── 1 Install Mobile AppSec tools ──► submenu: [Install all] [Select tools]
├── 2 Install Web AppSec tools ─────► submenu: [Install all] [Select tools]
├── 3 Install All tools ────────────► confirm → install everything (non-opt-in)
└── 4 Update existing tools ────────► list installed tools from manifest → confirm → update
```

- **Select tools** = `whiptail --checklist` where each row is `name  description`. Description comes from the catalog `description` field (enforce ≤ 48 chars in the schema test so rows fit an 80-col terminal). Append `(installed)` to tools already present. Default: all unticked except already-installed ones are shown ticked-and-greyed text, or simply left unticked — they're skipped anyway.
- Size the dialog from `tput lines/cols`; enable scrolling when the list is longer than the window.
- Each item also gets a category prefix or group separator (e.g. `── Recon ──`) so 40+ tools stay scannable. If whiptail can't render separators cleanly, sort by category and prefix the description with `[recon]`.
- Before installing, show a summary ("12 tools, ~1.4 GB, needs sudo for apt") and ask to confirm.
- Cancel/Esc at any level goes back one level; Esc on the main menu exits.
- Fallbacks: if `whiptail` is missing, offer to `apt install whiptail`; if declined or no TTY, use a numbered text prompt (`read`), where "Select tools" accepts `1,3,5-9` style input and prints the description next to each number.
- Menu mapping: Mobile = tag `mobile`; Web = tags `web`, `api`, `code`; All = everything not marked `opt_in: true`.
- The menu calls the same internal functions as `ait install --profile …`; no duplicated install logic.
- **On WSL only**, the main menu shows a 5th entry: `WSL networking: Mirrored [ON|OFF]` (see §2b). It is hidden on native Linux/macOS.

### 2b. WSL networking toggle (`ait wsl-net`)

Lets Windows and WSL share the same IP/localhost (mirrored mode), so a WSL agent can reach Burp/Ghidra MCP on Windows and Windows apps can reach WSL proxies, without port-forwarding.

```
ait wsl-net status      # current mode, Windows build, whether a restart is pending
ait wsl-net mirrored    # turn mirrored ON
ait wsl-net nat         # turn it OFF (back to default NAT)
ait wsl-net toggle      # flip
```

Behaviour:
1. Refuse unless running in WSL2. Check Windows build via `cmd.exe /c ver`; mirrored needs Windows 11 22H2+ (build ≥ 22621). On older builds, explain and exit without changes.
2. Locate `%UserProfile%\.wslconfig` via `cmd.exe /c echo %UserProfile%` + `wslpath`. Create it if missing.
3. Back up to `.wslconfig.ait-backup-<timestamp>` before every change.
4. Edit only the `networkingMode` key inside `[wsl2]` (add the section/key if absent). Preserve every other line, comment and key. Handle CRLF line endings. Write via a temp file + move.
5. `status` reads the file **and** the live state (e.g. compare `ip -4 addr` in WSL with Windows' IPs via `ipconfig.exe`) and reports "configured: mirrored, active: nat — restart pending" when they differ.
6. Changes apply only after `wsl --shutdown`. Print the command for the user to run in PowerShell. Offer (with a clear warning that it closes all WSL terminals, including this one) to run `wsl.exe --shutdown` itself; default No.
7. Print relevant notes: Windows Firewall/Hyper-V firewall may block inbound to WSL in mirrored mode; the same port can't be used on both sides at once; `hostAddressLoopback=true` is optional for host-IP loopback.
8. Supports `--dry-run` (show the diff, change nothing). Bats tests with fixture `.wslconfig` files (missing file, no `[wsl2]`, existing key, other keys present, CRLF).

### 2c. Windows companion (`windows/ait-windows.ps1`)

For GUI tools that run better natively on Windows. PowerShell script (no admin unless winget needs it) that:
- Offers a checklist (Out-GridView or numbered prompt) of Windows GUI tools via `winget`: Burp Suite (Community/Pro), Caido, jadx, Ghidra (+ Temurin JDK 21), scrcpy, Android platform-tools.
- Can set the same mirrored networking toggle from the Windows side (`-WslNetwork Mirrored|Nat`), same backup/edit rules as §2b.
- When `ait` detects WSL, the menu labels GUI apps "(recommended on Windows)" and leaves them unticked by default, pointing to this script.

---

## 3. Curated tool list (summary)

Full list with methods lives in the README catalog tables. Selection rules:
- Actively maintained (release or meaningful commit in the last ~18 months) **or** still best-in-class with no replacement.
- Solves a distinct problem — no five tools doing the same thing.
- Superseded tools are excluded and documented in `docs/not-included.md`:
  `tplmap → SSTImap`, `hakrawler/gospider → katana`, `cvemap → vulnx`, `LinkFinder → jsluice/xnLinkFinder`, `Sublist3r/assetfinder → subfinder`, `dirb/dirsearch → ffuf/feroxbuster`, `exa → eza`, `Corsy → nuclei templates`, apt `adb/apktool → upstream`.

Mobile must-haves the current repo lacks: upstream platform-tools, jadx release, Droid ASC (`droidasc` via `uv tool install droidasc`, Python ≥ 3.10, Apache-2.0) and rust_ASC (release binary `rust_ASC-linux-x86_64` / `-linux-aarch64` / `-macos-aarch64`, symlinked as `rust-asc`; fall back to `cargo build --release --locked` if no release is published), official apktool, uber-apk-signer, apk-mitm, reFlutter, hermes-dec, apkleaks, MobSF (docker), Ghidra, scrcpy, ipsw, ipatool, libimobiledevice, bagbak, and the `frida-server` + `proxy-ca` helpers.

**Frida 17 note:** Frida 17 moved the Java/ObjC bridges out of the core runtime, which broke older scripts and tool versions. Pin `frida-tools` and `objection` to a known-compatible pair in the catalog and have `ait doctor` warn on a mismatch between host `frida` and on-device `frida-server`.

---

## 4. Roadmap (phases)

Each phase ends with green CI and a tagged release.

**Phase 0 — Hygiene (v0.2.0)**
Fix B1–B13. Add LICENSE (MIT), `.editorconfig`, shellcheck config, `Makefile` (`make lint test`), basic CI running shellcheck. Replace README with the new one (mark not-yet-built features as "coming soon" until done).

**Phase 1 — Catalog engine (v0.3.0)**
`ait` entrypoint, `lib/core.sh` with honest `run()`, yq bootstrap, `catalog/tools.yaml` + `profiles.yaml`, resolver for `--profile/--with/--without`, `ait list`. Port existing tools into the catalog. Bats tests for schema and resolver.

**Phase 2 — Verified installers (v0.4.0)**
All install methods in `lib/methods/`, sha256 verification, per-arch asset maps, manifest-based uninstall, upstream runtimes (Go, rustup, uv, Node, JDK). `ait doctor` runs each tool's `check` and prints a table (+ `--json`).

**Phase 3 — Curated content (v0.5.0)**
Add the full curated web/api/code/mobile/iOS tool set, wordlists module, `docs/not-included.md`.

**Phase 4 — Mobile helpers (v0.6.0)**
`ait frida-server`, `ait proxy-ca`, WSL usbipd detection in doctor, optional Android cmdline-tools/emulator install.

**Phase 5 — UX & platforms (v0.7.0)**
Interactive menu per §2a (could be pulled forward to right after Phase 2 if you want to use it early), progress output, WSLg detection in `ait doctor` and `.desktop` launchers for GUI apps, `vps` profile (ulimits, tmux), macOS/Homebrew adapter (beta), Kali preference for current packages.

**Phase 6 — Release automation (v1.0.0)**
CI install matrix in containers (Ubuntu 22.04/24.04, Debian 12, Kali; `--profile web` and `--profile mobile` minus device steps), weekly `bump.yml` that opens version/checksum PRs, issue/PR templates, CHANGELOG, demo GIF (asciinema/vhs), GitHub topics & social preview.

**Phase 7 — Optional `ai` profile**
AI CLIs + MCP servers (Burp, Caido, Ghidra, Frida) with config snippets but no keys.

---

## 5. Definition of done (v1.0)
- `./ait install --profile all --yes` succeeds on a fresh Ubuntu 24.04 container with zero failures (excluding GUI/device-only checks).
- `--dry-run` provably changes nothing (test).
- Every release binary is checksum-verified.
- `ait doctor` green after install; `ait uninstall` leaves no managed files behind.
- shellcheck clean, bats suite passing, CI badge green, README accurate to the code.
