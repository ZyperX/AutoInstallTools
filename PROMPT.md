# PROMPT.md — Build AutoInstallTools (AIT) end to end

You are a senior DevSecOps engineer and Bash expert. You are building **AutoInstallTools** (`ait`) — https://github.com/ZyperX/AutoInstallTools — a polished, trustworthy, GitHub-worthy installer that sets up a complete **web + mobile application-security pentesting** workstation. The primary user is an AppSec pentester who is strong in web and mobile (Android/iOS) testing and works on Ubuntu/Kali, often inside **WSL2 on Windows**, plus a headless VPS for heavy recon.

This file is the complete spec. Everything you need is here.

---

## 0. First: take stock of the repo

The repo may already contain earlier work (a Phase 0 bug-fix pass, a Phase 1 catalog engine with `ait`, `catalog/tools.yaml`, `catalog/profiles.yaml`, `lib/catalog.sh`, `lib/dispatch.sh`, tests). Before writing code:

1. Read the whole repo and every open branch/PR. Report what of §5 (phases) is already done, partially done or missing. **Build on existing work instead of rewriting it**, unless it contradicts this spec.
2. **Unknown files:** if the working copy has untracked files you didn't create, don't commit, move or delete them. List each one with its size, modification time and first 20 lines, and wait for the user. Never use `git add -A` or `git add .`; stage files by explicit path.
3. Post a short status + plan, then start with the first unfinished phase.

---

## 1. Working rules

- **Phase by phase** (§5). One branch + one PR per phase, pushed to GitHub (§8). Small conventional commits. Don't start the next phase until CI is green. Never change repo settings or bypass branch protection.
- Before each phase post a short plan (files, risks); after it a PR summary (what changed, tools added, tools left out and why, decisions needed).
- **Verify every tool upstream at implementation time**: repo, release asset names per arch, checksum file, binary name, Go module path, PyPI/npm/crate name, current major version, maintenance status. Never guess. If a tool is archived, broken, or can't be installed automatically, leave it out and record why in `docs/not-included.md`.
- Bash 5, `set -Euo pipefail`, shellcheck-clean (no blanket disables). Quote everything. No `eval` on catalog data. No `curl | bash` from third parties.
- **Every side-effecting command goes through `run()`** so `--dry-run` is truthful. A test must prove dry-run changes nothing.
- `sudo` only for system packages and repo keys, announced before first use. Everything else in user space: `~/.local/bin`, `~/.local/share/ait`.
- **Idempotent:** a second run is a no-op apart from "already installed" lines. Failures are recorded and summarised; the run continues; print a one-line retry command.
- Never store credentials, tokens, targets or scan data. Never auto-accept licences (e.g. Burp) without an explicit choice and a prompt.
- Readable for contributors: small functions, one install method per file, comments only where intent isn't obvious.
- Known Bash traps (already hit in this repo): `trap … RETURN` inside functions leaks to later returns → use subshell functions; `cmd | grep -q` under `pipefail` gives SIGPIPE false negatives → capture then grep; tab-`IFS` `read` collapses empty columns → never emit empty TSV fields.

---

## 2. Architecture

```
AutoInstallTools/
├── ait                         # single entrypoint (bash)
├── catalog/
│   ├── tools.yaml              # source of truth for every tool
│   └── profiles.yaml           # profile/menu → tags
├── lib/
│   ├── core.sh                 # logging, run(), retry, lock, state, OS/arch/WSL detection
│   ├── catalog.sh              # pinned+sha256-verified yq bootstrap, resolver, field getters
│   ├── verify.sh               # sha256 + checksum-file parsing
│   ├── menu.sh                 # interactive menu (whiptail + text fallback)
│   ├── wslnet.sh               # WSL mirrored-networking toggle
│   ├── dispatch.sh             # method → function table only
│   └── methods/                # apt brew github_release go uv npm cargo git git_venv docker official_archive wget_mirror runtime manual
├── helpers/
│   ├── frida-server.sh
│   └── proxy-ca.sh
├── windows/ait-windows.ps1     # Windows companion for GUI tools
├── scripts/pin.sh              # dev: fill version/asset/sha256 from upstream
├── config/                     # tmux.conf, shell snippet, safe aliases
├── docs/                       # adding-tools.md, not-included.md, wsl.md, troubleshooting.md
├── tests/                      # bats-core suites + fixtures
├── .github/{workflows/ci.yml, workflows/bump.yml, ISSUE_TEMPLATE/, PULL_REQUEST_TEMPLATE.md}
└── README.md CONTRIBUTING.md SECURITY.md CHANGELOG.md LICENSE (MIT) Makefile .editorconfig .shellcheckrc
```

`install.sh`, `update.sh`, `doctor.sh`, `uninstall.sh` stay as thin deprecated wrappers around `ait` (one-line deprecation notice).

### 2.1 Catalog schema (`catalog/tools.yaml`)

```yaml
tools:
  - name: droidasc                 # unique id; = command unless `bin` given
    desc: Fast on-demand APK search & decompile   # REQUIRED, <= 48 chars, shown in the picker
    category: android              # REQUIRED: core|runtime|recon|proxy|discovery|vuln|api|js-secrets|sast-sca|android|ios|reversing|wordlists|cloud|container|ai
    tags: [mobile]                 # REQUIRED: core|runtime|recon|web|api|code|mobile|cloud|wordlists|ai
    method: uv                     # REQUIRED: see lib/methods/
    bin: droidasc                  # optional
    check: droidasc -h             # REQUIRED health check, must exit 0
    gui: false                     # true → on WSL: "(recommended on Windows)", unticked by default
    opt_in: false                  # true → only via --with or manual selection
    platforms: [linux, wsl, macos] # default [linux, wsl]
    apt_deps: []                   # system packages needed first (e.g. libpcap-dev)
    notes: ""                      # e.g. "superseded by katana"
    # method-specific: apt: [...] | go: <module> | repo: owner/name | pypi: | npm: | crate: | git: <url> | image: | url: | dest: | runtime:
    # pinning (github_release, official_archive):
    version: v1.2.3
    asset:  { linux_amd64: "...", linux_arm64: "...", darwin_arm64: "..." }
    sha256: { linux_amd64: "...", linux_arm64: "...", darwin_arm64: "..." }   # or checksum_file: <asset>
```

`catalog/profiles.yaml`:
```yaml
profiles:
  minimal: [core, runtime]
  mobile:  [core, runtime, mobile]
  web:     [core, runtime, recon, web, api, code, wordlists]
  api:     [core, runtime, api]
  code:    [core, runtime, code]
  vps:     [core, runtime, recon, wordlists]       # never gui tools
  all:     [core, runtime, recon, web, api, code, mobile, cloud, wordlists]   # excludes opt_in
  ai:      [ai]                                    # opt-in, not part of all
```

Resolver: profile → tags → tools, `+ --with`, `- --without`; `opt_in` only via `--with`/manual pick; filter by detected platform; unknown names → error with "did you mean"; deterministic order (runtimes and `apt_deps` first, then category, then name).

---

## 3. Features

### 3.1 CLI

```
ait                                   # interactive menu (§3.2)
ait install [--profile P] [--with a,b] [--without c] [--dry-run] [--yes] [--no-shell]
ait list [--profile P] [--category C] [--installed] [--json]
ait doctor [--json]
ait update [--tools a,b]
ait uninstall [--tools a,b | --all] [--apt]
ait frida-server [--device SERIAL]
ait proxy-ca --burp|--caido|--mitmproxy [CERT]
ait wsl-net status|mirrored|nat|toggle         # WSL only
```

### 3.2 Interactive menu — the main way the user uses AIT

Running `./ait` with no arguments:

```
Main menu
├── 1 Install Mobile AppSec tools ─► [Install all] [Select tools]
├── 2 Install Web AppSec tools ────► [Install all] [Select tools]
├── 3 Install All tools ───────────► confirm → install profile `all`
├── 4 Update existing tools ───────► list tools from the manifest → confirm → update
└── 5 WSL networking: Mirrored [ON|OFF]     # shown only on WSL (§3.4)
```

- Mobile = profile `mobile`; Web = profile `web`; All = profile `all`.
- **Select tools** = `whiptail --checklist`. Each row: tool name with its `desc` **right beside it**, plus `(installed)` for tools already present. Group by `category` (sort by category; header rows like `── android ──`, or a `[category]` prefix if whiptail can't render separators). On WSL, `gui: true` tools show `(recommended on Windows)` and start unticked. Include `opt_in` tools in the list (unticked).
- Size the dialog from `tput lines/cols`; scroll when longer than the window.
- Before installing, show a summary (tool count, needs sudo yes/no, rough download size if known) and confirm.
- Esc/Cancel goes back one level; Esc on the main menu exits.
- Fallback when `whiptail` is missing or there's no TTY: offer `sudo apt install whiptail`; if declined, a numbered text menu where Select tools prints `N) name — desc` and accepts `1,3,5-9`.
- The menu calls the same functions as the CLI flags; no duplicated install logic.

### 3.3 Install methods & verification

- Methods in `lib/methods/`: `apt`, `brew` (macOS, beta), `github_release`, `go`, `uv` (pipx fallback), `npm` (user prefix, never `sudo npm`), `cargo`, `git` (clone only), `git_venv` (clone + isolated venv + wrapper in `~/.local/bin`), `docker` (pull + wrapper, never `--privileged`), `official_archive` (vendor URL + sha256), `wget_mirror`, `runtime`, `manual` (print instructions, mark as manual).
- `github_release` asset choice: exact per-arch name from the catalog; fallback matcher handles `amd64|x86_64|x64|64bit` and `arm64|aarch64`, Linux only, skips `.deb .rpm .sig .asc .sbom .sha256 checksums .txt .json` etc., prefers archives.
- **Verify sha256 before extracting.** Mismatch → delete, record failure, never install. Entries without `version` install latest with an "unpinned" warning.
- `scripts/pin.sh <tool>|--all` fills `version`, `asset`, `sha256` from upstream. CI fails if a pinned entry lacks a checksum for a declared platform.
- Runtimes from upstream, skipped if a new enough one exists: official Go tarball (checksum from go.dev) + `GOTOOLCHAIN=auto`; rustup; `uv`; Node 22 LTS; Temurin/OpenJDK 21. Never use apt's Go/Rust.
- Prefer release binaries over `go install` where releases exist.
- **Manifest:** every install appends to `~/.local/share/ait/state/manifest.tsv` (`tool method version paths installed_at`). Uninstall removes exactly those paths and the marked shell-rc block; uses `uv tool uninstall` / `npm rm -g` / `cargo uninstall`; apt packages only with `--apt` + confirmation.
- Shell setup: one clearly marked block in `.bashrc`/`.zshrc` sourcing `~/.local/share/ait/shell.sh` (copied there, not sourced from the clone). Aliases must never shadow core commands (`cat`, `find`, `ls` behaviour in scripts).

### 3.4 WSL support

**GUI tools.** WSLg runs Linux GUI apps as Windows windows (Windows 11, or 10 22H2 with Store WSL). For GUI tools: install `.desktop` launchers so they appear in the Windows Start menu; document HiDPI scaling (`GDK_SCALE=2`, `-Dsun.java2d.uiScale=2` for Java apps). Daily-driver GUI apps (Burp, Caido desktop) run better natively on Windows, so on WSL the menu marks `gui: true` tools "(recommended on Windows)" and points to the Windows companion.

**`ait wsl-net` — mirrored networking toggle** (Windows and WSL share one IP/localhost, so a WSL agent can reach Burp/Ghidra MCP on Windows and Windows apps can reach WSL proxies):
1. Only on WSL2. Check the Windows build via `cmd.exe /c ver`; mirrored needs build ≥ 22621 (Windows 11 22H2). Otherwise explain and change nothing.
2. Find `%UserProfile%\.wslconfig` (`cmd.exe /c echo %UserProfile%` + `wslpath`); create if missing.
3. Back up to `.wslconfig.ait-backup-<timestamp>` before every change.
4. Edit only `networkingMode` under `[wsl2]` (add section/key if absent); preserve all other lines, comments and keys; CRLF-safe; write via temp file + move.
5. `status` reports configured mode **and** live mode (compare WSL `ip -4 addr` with `ipconfig.exe`) and says "restart pending" when they differ.
6. Changes apply after `wsl --shutdown`. Print the PowerShell command. Offer to run `wsl.exe --shutdown` only with an explicit yes and a warning that it closes all WSL terminals including this one; default No.
7. Print notes: Windows/Hyper-V firewall may block inbound to WSL; the same port can't be bound on both sides; `hostAddressLoopback=true` is optional.
8. `--dry-run` shows the diff only. Bats fixtures: missing file, no `[wsl2]`, existing key, other keys present, CRLF.

**adb on WSL:** detect whether the phone is reachable (usbipd-attached USB, or `adb connect` over Wi-Fi), or whether Windows' adb server should be used (`ADB_SERVER_SOCKET=tcp:localhost:5037` with mirrored mode). Warn that Windows and WSL adb servers fight over port 5037; use one side only.

**Windows companion `windows/ait-windows.ps1`** (PowerShell, no admin unless winget needs it): checklist (Out-GridView or numbered prompt, with descriptions) of Windows-native GUI tools via `winget`: Burp Suite Community/Pro, Caido, jadx, Ghidra + Temurin JDK 21, scrcpy, Android platform-tools, rust_ASC Windows binary. Also `-WslNetwork Mirrored|Nat` with the same backup/edit rules. Lint with PSScriptAnalyzer in CI.

### 3.5 Mobile helpers

- `ait frida-server`: read host `frida --version`, device ABI via `adb shell getprop ro.product.cpu.abi`, download the matching `frida-server` release, verify, push to `/data/local/tmp`, `chmod 755`, start (root via `su -c` when available), confirm with `frida-ps -U`. Frida 17 moved the Java/ObjC bridges out of the core runtime; pin a compatible `frida-tools` + `objection` pair in the catalog and warn on host/device version mismatch.
- `ait proxy-ca`: export the Burp/Caido/mitmproxy CA, convert to PEM `<subject_hash_old>.0`, and print install steps for the user store and system store, including Android 14+ (APEX `conscrypt` cacerts) notes.

### 3.6 `ait doctor [--json]`
Runs each installed tool's `check` (10 s timeout) → table: name, version, status (ok / broken / missing / unpinned / outdated). Extra checks: `~/.local/bin` and `~/go/bin` on PATH; WSL + WSLg (`/mnt/wslg`); `wsl-net` mode; adb reachability; Frida host/device mismatch; nuclei templates older than 14 days; disk space.

### 3.7 `ait update`
Only tools in the manifest. Pinned tools: install the catalog version if it differs from the manifest. Also `nuclei -update-templates`, wordlist `git pull`s, `uv tool upgrade --all` for unpinned Python tools.

### 3.8 VPS profile
Headless: no GUI tools, raise `nofile` limits, ship a tmux config, recon-heavy defaults.

---

## 4. Tool catalog (curated)

Selection rules: actively maintained (release or meaningful commit in ~18 months) or still best-in-class with no replacement; each tool solves a distinct problem. Verify each upstream; adjust the method if upstream differs. `opt` = `opt_in: true`.

**core / CLI:** curl, git, jq, yq (mikefarah, pinned), ripgrep, fd, bat, eza, fzf, zoxide, tmux, btop, tree, socat, httpie, gron, anew, unfurl, qsreplace, uro, whiptail
**runtime:** go, rust (rustup), uv, python3, node 22 LTS, jdk 21
**proxy:** caido-cli (+ caido desktop, gui), mitmproxy (uv), burp (manual/official installer, gui, opt), zap (gui, opt)
**recon:** subfinder, dnsx, httpx, naabu (apt_deps libpcap-dev), katana, tlsx, cdncheck, asnmap, uncover, alterx, mapcidr, urlfinder, gau, waymore (uv), puredns + massdns, gowitness, nmap (apt), amass (opt), rustscan (opt)
**discovery:** ffuf, feroxbuster, x8, arjun (uv), kiterunner, nomore403
**vuln:** nuclei, interactsh-client, vulnx, sqlmap, ghauri (uv), dalfox, sstimap (git_venv), commix (git_venv), smuggler (git_venv, opt)
**api:** jwt_tool (git_venv), graphw00f (git_venv), clairvoyance (uv), graphql-cop (git_venv), hurl (opt)
**js-secrets:** jsluice (go), xnlinkfinder (uv), sourcemapper (go), trufflehog, gitleaks
**sast-sca:** opengrep, semgrep (uv, opt), osv-scanner, trivy, syft, grype, codeql (opt)
**android:** android-platform-tools (official_archive from Google, not apt), scrcpy (gui), jadx + jadx-gui (gui), **droidasc** (uv, PyPI `droidasc`, Python ≥ 3.10 — https://github.com/MG1937/ASC, desc "Fast on-demand APK search & decompile"), **rust-asc** (https://github.com/MG1937/rust_ASC; github_release if releases are published — assets `rust_ASC-linux-x86_64`, `rust_ASC-linux-aarch64`, `rust_ASC-macos-aarch64` — else `cargo build --release --locked` from a pinned tag/commit; bin `rust-asc`; desc "Rust ASC: 10x faster, full APK decompile"), apktool (official jar + wrapper, not apt), uber-apk-signer (jar + wrapper), frida-tools (uv), objection (uv), apk-mitm (npm), reflutter (uv), hermes-dec (uv), apkleaks (uv), medusa (git_venv, opt), blutter (opt), mobsf (docker, opt), android cmdline-tools + emulator (opt)
**ios:** libimobiledevice-utils (apt), ipsw, ipatool, bagbak (npm), grapefruit (npm, opt)
**reversing:** ghidra (official_archive, gui, tags [mobile], opt — large download)
**wordlists:** seclists, payloadsallthethings, onelistforall, resolvers list; assetnote (wget_mirror, opt, large)
**cloud/container (opt unless already default):** awscli v2, docker, docker-compose plugin (Docker's repo), lazydocker, dive, k9s, kubectx
**ai (profile `ai`, opt):** claude-code, opencode, aider, llm; MCP servers for Burp (PortSwigger extension, manual), Caido, Ghidra (GhidraMCP), Frida — config snippets only, never API keys

**Superseded → `opt_in: true` + `notes: "superseded by X"`, or drop and list in `docs/not-included.md`:** hakrawler/gospider → katana; assetfinder/Sublist3r → subfinder; waybackurls → gau/urlfinder; dirsearch/gobuster/dirb → ffuf/feroxbuster; tplmap → sstimap; LinkFinder → jsluice/xnlinkfinder; cvemap → vulnx; exa → eza; shell-gpt → llm; apt `adb`/`apktool`/`golang`/`rustc` → upstream.

Every `desc` ≤ 48 chars, plain English, no marketing.

---

## 5. Phases

Each ends with green CI and a tagged release. Skip any phase already done (§0).

**Phase 0 — Hygiene (v0.2.0).** Fix existing bugs: Arjun installed via `go install` (it's Python); Go/Rust from apt (too old); `update.sh` not sourcing `lib/apt.sh`; `--dry-run` not wired to `run()`; GitHub asset matcher only matching `amd64` and picking `.deb`/`.sig`/checksum files, no verification; non-existent apt names (`feroxbuster`, `jadx`, `dex2jar`, `awscli` on 24.04, `docker-compose-plugin` without Docker's repo, mikefarah `yq`); `naabu` missing `libpcap-dev`; stale amass module path; `--full`/`--mobile` overlap; `update.sh` not running `pdtm -ua`/template updates; archived `exa`; `cat`/`find` aliases breaking commands; rc file sourcing aliases from the clone path; `doctor.sh` only checking `command -v`; README placeholders. Add LICENSE, `.editorconfig`, `.shellcheckrc`, Makefile (`lint`, `test`), shellcheck CI.

**Phase 1 — Catalog engine (v0.3.0).** `ait` entrypoint, `lib/catalog.sh` (pinned yq bootstrap, resolver, getters), `catalog/tools.yaml` + `profiles.yaml` per §2.1 including `category` and `gui`, `ait list`, deprecated wrappers. Populate the catalog with **all of §4** (methods not built yet report "method not implemented"). Tests: schema, resolver, dry-run, `ait list` snapshot.

**Phase 2 — Verified installers (v0.4.0).** All methods in `lib/methods/`, pinning + sha256 (§3.3), `scripts/pin.sh`, upstream runtimes, manifest + `ait uninstall`, full `ait doctor` (§3.6), `ait update` (§3.7).

**Phase 3 — Interactive menu (v0.5.0).** §3.2 exactly, including the text fallback. Bats tests for the text fallback and menu → profile mapping.

**Phase 4 — Mobile helpers (v0.6.0).** `ait frida-server`, `ait proxy-ca`, adb/WSL detection (§3.4, §3.5).

**Phase 5 — WSL & Windows (v0.7.0).** `ait wsl-net` + menu entry 5, `.desktop` launchers, WSLg checks, `windows/ait-windows.ps1`, `docs/wsl.md`.

**Phase 6 — Platforms & VPS (v0.8.0).** Kali (prefer Kali packages when current), Debian 12, macOS/Homebrew beta, VPS profile tuning (§3.8).

**Phase 7 — Release polish (v1.0.0).** CI matrix in containers (Ubuntu 22.04, 24.04, Debian 12, Kali) running `ait install --profile mobile --yes` and `--profile web --yes` (GUI/device checks allowed to fail; upload the failure summary as an artifact). Weekly `bump.yml` that runs `scripts/pin.sh --all` and opens a PR. Issue templates (bug, tool request), PR template, CONTRIBUTING (inclusion criteria, adding a tool = one YAML entry), SECURITY.md, CHANGELOG, terminal demo GIF via `vhs`, final README.

---

## 6. Tests & CI

- bats-core (vendored under `tests/bats/` or installed in CI). Mock network and package managers with a fake `PATH`.
- Required suites: catalog schema (required fields, unique names, `desc` ≤ 48, valid enums, pinned entries have per-platform sha256); resolver; dry-run changes nothing (`$HOME`, `/usr`, package DB); checksum good/tampered; manifest install→uninstall round trip; each method; menu text fallback; `wsl-net` fixtures; `ait list` snapshot.
- `make lint test integration`. CI: shellcheck, bats, PSScriptAnalyzer, integration matrix (Phase 7).

---

## 7. README.md — detailed, accurate, GitHub-worthy

`README.md` is the project's front page and must be **detailed**. A reference draft is in **Appendix A** at the end of this file: use it as the starting point and structure, then make it match the real code and catalog (fix any names, flags, profiles or tools that differ). Keep it updated in every phase; mark features not built yet as "coming soon" and remove those markers as they land.

Required sections, in this order:
1. Title, one-line pitch, badges (CI status, platforms, shell, licence, latest release).
2. **Why this exists**: the problem, and what's different (curated, catalog-driven, verified, idempotent, user-space, mobile first-class).
3. Authorized-use warning.
4. **Quick start**: `git clone https://github.com/ZyperX/AutoInstallTools.git && cd AutoInstallTools && ./ait`, then `exec $SHELL` and `ait doctor`.
5. **Interactive menu**: ASCII mock-ups of the main menu, the Install all / Select tools submenu, and the checklist with descriptions beside each tool; what each choice installs; keyboard keys; text fallback.
6. Non-interactive usage (`--profile`, `--with`, `--without`, `--dry-run`, `--yes`) with examples.
7. Supported platforms table (Ubuntu 22.04/24.04, Debian 12, Kali, WSL2, macOS beta) and architectures.
8. Profiles table.
9. **Full tool catalog**: one table per category (tool linked to upstream, what it's for, install method, default profile). Generate these tables from `catalog/tools.yaml` with `scripts/gen-readme.sh` between `<!-- catalog:start -->` / `<!-- catalog:end -->` markers; CI fails if they're stale.
10. "Deliberately not included", linking to `docs/not-included.md`.
11. Commands table (every `ait` subcommand and flag).
12. **GUI tools on WSL2**: WSLg requirements, launching, Start-menu launchers, HiDPI, "recommended on Windows".
13. **Mirrored networking**: `ait wsl-net`, the menu entry, requirements, firewall/port notes.
14. **Windows companion**: `windows/ait-windows.ps1` usage.
15. **Mobile testing**: Android device setup on WSL (usbipd / adb over Wi-Fi), `ait frida-server`, `ait proxy-ca` including Android 14+, iOS from Linux vs macOS.
16. VPS usage.
17. Updating, uninstalling, logs and state locations.
18. **Adding a tool**: YAML example + link to `docs/adding-tools.md`.
19. Safety & supply chain (pinning, sha256, no `curl | bash`, sudo scope, no secrets stored).
20. Troubleshooting (top 5 problems) + link to `docs/troubleshooting.md`.
21. FAQ, Contributing, Licence (each tool keeps its own licence).

Also: put a demo GIF (recorded with `vhs`, tape file `docs/demo.tape`) near the top in Phase 7; check every README link in CI (e.g. `lychee`); keep tables readable on GitHub's mobile view.

---

## 8. Git & GitHub — push everything

All work must end up on GitHub at https://github.com/ZyperX/AutoInstallTools. Nothing stays only local.

- Use the `gh` CLI (or git over HTTPS with the configured credentials). Run `gh auth status` first; if you're not authenticated or a push is denied, stop and tell the user exactly what's needed. Don't work around it.
- For each phase: create branch `phase-N-<slug>`, commit by explicit paths (never `git add -A` / `git add .`), **push the branch**, and **open a PR** with `gh pr create` (title "Phase N: …"; body = what changed, tools added/removed, how to test, decisions needed). Stack on the previous phase's branch if it isn't merged yet; retarget to `main` once it is.
- Push after every meaningful commit so work is never only on the local machine.
- Wait for CI on the PR (`gh pr checks --watch`) and fix failures before moving on.
- **Merging into `main`:** if the user has said to merge, or branch protection lets you, merge with `gh pr merge --squash --delete-branch` once CI is green. If merging is blocked by policy or required reviews, don't bypass it or change settings: tell the user the PR is ready and continue on a stacked branch.
- After each phase merges: tag it (`v0.2.0` … `v1.0.0`), push the tag, and create a GitHub release with `gh release create`, using that version's CHANGELOG section as the notes.
- Repo polish (Phase 7; via `gh repo edit` if you have permission, otherwise list the settings for the user): description "One-command web + mobile AppSec pentest toolkit installer", topics (`pentesting`, `appsec`, `bug-bounty`, `mobile-security`, `android-security`, `web-security`, `wsl`, `installer`, `bash`), social preview image.
- Final check: `main` contains every phase, the README renders correctly on github.com (open it and look), the CI badge is green, and the latest release is `v1.0.0`.

---

## 9. Definition of done (v1.0)

- `./ait` opens the menu; Mobile/Web → Install all / Select tools with descriptions beside each tool; All; Update existing; WSL networking toggle on WSL.
- `./ait install --profile mobile --yes` on clean Ubuntu 24.04 installs jadx, droidasc, rust-asc, apktool, frida-tools, objection, apk-mitm, platform-tools with zero failures; same for `--profile web` with its core tools.
- Every `github_release`/`official_archive` tool is pinned and checksum-verified.
- `--dry-run` provably changes nothing; second run is a no-op.
- `ait doctor` green after install; `ait uninstall --all` leaves no AIT-managed files.
- shellcheck, bats, PSScriptAnalyzer and the integration matrix green.
- A detailed `README.md` (§7) that matches the code, with generated catalog tables and a passing link check.
- Everything pushed to GitHub: all phases merged into `main` (or PRs ready if merging is blocked), tags and GitHub releases up to `v1.0.0`.

**Start now with §0.**

---

## Appendix A — Reference README draft

Starting point for `README.md` (§7). Adapt it to the real code and catalog; don't copy claims that aren't true yet.

````markdown
<div align="center">

# AutoInstallTools

**One command to set up a complete, modern web + mobile AppSec workstation.**

Curated tools only. Pinned and checksum-verified. Safe to re-run. Easy to remove.

[![CI](https://github.com/ZyperX/AutoInstallTools/actions/workflows/ci.yml/badge.svg)](https://github.com/ZyperX/AutoInstallTools/actions/workflows/ci.yml)
![Platforms](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian%20%7C%20Kali%20%7C%20WSL2%20%7C%20macOS-blue)
![Shell](https://img.shields.io/badge/shell-bash%205%2B-green)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

</div>

---

## Why this exists

Every new laptop, VM, WSL distro or VPS costs a pentester half a day: hunting the right `go install` path, discovering apt ships a three-year-old `apktool`, matching `frida-server` to the device, fixing `PATH`. AutoInstallTools turns that into one command and a coffee.

What makes it different from the hundred other "install-all-the-tools" scripts:

- **Curated, not hoarded.** Every tool earns its place. Abandoned or superseded tools are left out or marked as such (e.g. `tplmap` → `SSTImap`, `hakrawler` → `katana`, `cvemap` → `vulnx`).
- **Declarative catalog.** All tools live in [`catalog/tools.yaml`](catalog/tools.yaml): one entry per tool with its install method, version, profile and a health check. Adding a tool is a 6-line PR.
- **Verified installs.** Release binaries are pinned and SHA-256 checked. `ait update` bumps pins deliberately, not silently.
- **User-space first.** Everything lands in `~/.local`, `~/go/bin` and `~/.local/share/ait`. `sudo` is only used for apt packages and is always announced first.
- **Idempotent and recoverable.** Re-run as often as you like. Failures never stop the run; you get a summary and a one-line retry command.
- **Mobile is a first-class citizen.** Correct `platform-tools`, `jadx`, `apktool`, Frida 17-compatible tooling, an `ait frida-server` helper that pushes the right build to your device, and honest notes for iOS from Linux.

> ⚠️ **Authorized use only.** These tools are for systems you own or have written permission to test. You are responsible for how you use them.

---

## Quick start

```bash
git clone https://github.com/ZyperX/AutoInstallTools.git
cd AutoInstallTools
./ait                        # opens the interactive menu
```

### Interactive menu

Running `./ait` with no arguments opens a keyboard-driven menu:

```
┌──────────── AutoInstallTools ────────────┐
│  1  Install Mobile AppSec tools          │
│  2  Install Web AppSec tools             │
│  3  Install All tools                    │
│  4  Update existing tools                │
└──────────────────────────────────────────┘
```

Choosing **Mobile** or **Web** asks how you want to install:

```
┌──────── Web AppSec tools (42) ───────────┐
│  1  Install all Web AppSec tools         │
│  2  Select tools                         │
└──────────────────────────────────────────┘
```

**Select tools** opens a checklist with a short description beside every tool. Already-installed tools are marked. Use `↑/↓` to move, `Space` to tick, `Enter` to install:

```
┌──────────────── Select Web AppSec tools ────────────────┐
│ [*] caido        Modern web proxy (desktop + CLI)       │
│ [*] ffuf         Fast general-purpose web fuzzer        │
│ [ ] feroxbuster  Recursive content discovery            │
│ [*] nuclei       Template-based vuln scanner (installed)│
│ [ ] jwt_tool     JWT analysis & attacks                 │
│ [ ] x8           Hidden parameter discovery             │
│                         ...                             │
└─────────────────────────────────────────────────────────┘
```

**All tools** installs everything (after one confirmation). **Update existing** updates only the tools AutoInstallTools has already installed, plus nuclei templates and wordlists.

What each menu covers:

| Menu choice | Catalog tags included |
|---|---|
| Mobile AppSec | `mobile` (Android + iOS host tooling, Frida stack, decompilers, MobSF) |
| Web AppSec | `web`, `api`, `code` (proxies, recon, fuzzing, injection, API/GraphQL/JWT, JS & secrets, SAST/SCA) |
| All tools | everything except opt-in extras |

The menu works over SSH and in WSL. If `whiptail` isn't available it falls back to a numbered text prompt.

### Non-interactive (scripts, CI, VPS)

```bash
./ait install --profile web           # web AppSec workstation
./ait install --profile mobile        # Android + iOS host tooling
./ait install --profile all          # web + mobile + api + code review
./ait install --profile vps           # headless recon box (no GUI apps)
./ait install --profile web --with ghidra,codeql --without amass
./ait install --profile all --dry-run   # show exactly what would happen
```

Then:

```bash
exec $SHELL          # reload PATH
ait doctor           # verify everything works
```

---

## Supported platforms

| Platform | Status | Notes |
|---|---|---|
| Ubuntu 22.04 / 24.04 | ✅ Primary | Tested in CI |
| Debian 12 | ✅ Supported | Tested in CI |
| Kali Linux (rolling) | ✅ Supported | Prefers Kali's own packages where they are current |
| WSL2 (Ubuntu) | ✅ Supported | GUI apps via WSLg; USB devices via `usbipd-win` (see [Mobile on WSL](#mobile-testing-on-wsl2)) |
| macOS 14+ (Apple Silicon/Intel) | 🧪 Beta | Uses Homebrew; required for most iOS tooling |
| Arch / Fedora | ❌ Not yet | PRs welcome |

Architectures: `x86_64` and `arm64` (`aarch64`).

---

## Profiles

Profiles are bundles of catalog tags. Combine them, or fine-tune with `--with` / `--without`.

| Profile | For | Includes |
|---|---|---|
| `minimal` | Any box | Core CLI utilities, runtimes (Go, Python via `uv`, Node LTS, JDK 21) |
| `web` | Web & API testing | minimal + proxies, API, code review, recon, discovery, fuzzing, injection, auth, secrets, wordlists |
| `api` | API-focused engagements | minimal + API/GraphQL/JWT tooling and discovery |
| `mobile` | Android & iOS | minimal + Android SDK tools, decompilers, Frida stack, Flutter/RN tooling, iOS host tools |
| `code` | Source review / SAST / SCA | minimal + Opengrep/Semgrep, secrets scanners, SBOM & dependency scanners |
| `vps` | Headless recon server | minimal + recon + nuclei, no GUI apps, tuned for long runs in `tmux` |
| `ai` | Agent-assisted testing | AI coding CLIs + MCP servers for Burp, Caido, Ghidra and Frida (opt-in) |
| `all` | Everything above except `ai` and opt-in extras | web + api + mobile + code |

Run `ait list --profile web` to see the exact contents of any profile.

---

## Tool catalog

Every tool below is defined in `catalog/tools.yaml`. **Method** is how it is installed; **Default** shows which profiles include it (`opt` = only with `--with`).

### Intercepting proxies

| Tool | What it's for | Method | Default |
|---|---|---|---|
| [Caido](https://caido.io) | Modern, fast web proxy (desktop + headless CLI) | release | web, api, mobile |
| [Burp Suite](https://portswigger.net/burp) | Industry-standard proxy (Community or Pro) | official installer, prompts first | opt |
| [mitmproxy](https://mitmproxy.org) | Scriptable proxy, great for mobile and automation | uv | web, mobile |
| [ZAP](https://www.zaproxy.org) | OSS proxy and DAST scanner | release | opt |

### Recon & attack-surface mapping

| Tool | What it's for | Method | Default |
|---|---|---|---|
| [subfinder](https://github.com/projectdiscovery/subfinder) | Passive subdomain enumeration | release | web, vps |
| [dnsx](https://github.com/projectdiscovery/dnsx) | Fast DNS resolution & probing | release | web, vps |
| [puredns](https://github.com/d3mondev/puredns) + [massdns](https://github.com/blechschmidt/massdns) | Wildcard-aware brute force & resolution | go / source | vps |
| [alterx](https://github.com/projectdiscovery/alterx) | Subdomain permutation generation | release | vps |
| [httpx](https://github.com/projectdiscovery/httpx) | HTTP probing, tech detection, screenshots | release | web, vps |
| [naabu](https://github.com/projectdiscovery/naabu) | Fast port scanning | release | web, vps |
| [tlsx](https://github.com/projectdiscovery/tlsx) / [cdncheck](https://github.com/projectdiscovery/cdncheck) / [asnmap](https://github.com/projectdiscovery/asnmap) | TLS data, CDN/WAF detection, ASN ranges | release | vps |
| [uncover](https://github.com/projectdiscovery/uncover) | Query Shodan/Censys/FOFA etc. from the CLI | release | vps |
| [katana](https://github.com/projectdiscovery/katana) | Crawler with headless & JS parsing | release | web, vps |
| [urlfinder](https://github.com/projectdiscovery/urlfinder) / [gau](https://github.com/lc/gau) / [waymore](https://github.com/xnl-h4ck3r/waymore) | Historical URLs from passive sources | release / go / uv | web, vps |
| [gowitness](https://github.com/sensepost/gowitness) | Screenshot & triage many hosts | release | vps |
| [amass](https://github.com/owasp-amass/amass) | Deep OSINT enumeration (heavy) | release | opt |
| [nmap](https://nmap.org) | Network & service scanning | apt | minimal |
| [rustscan](https://github.com/RustScan/RustScan) | Very fast port discovery | release | opt |

### Content discovery & fuzzing

| Tool | What it's for | Method | Default |
|---|---|---|---|
| [ffuf](https://github.com/ffuf/ffuf) | The general-purpose web fuzzer | release | web, api |
| [feroxbuster](https://github.com/epi052/feroxbuster) | Recursive content discovery | release | web |
| [x8](https://github.com/Sh1Yo/x8) | Hidden parameter discovery | release | web, api |
| [Arjun](https://github.com/s0md3v/Arjun) | Parameter discovery | uv | web, api |
| [kiterunner](https://github.com/assetnote/kiterunner) | API route discovery with real-world route lists | release | api |
| [nomore403](https://github.com/devploit/nomore403) | 401/403 bypass techniques | release | web |

### Vulnerability scanning & exploitation helpers

| Tool | What it's for | Method | Default |
|---|---|---|---|
| [nuclei](https://github.com/projectdiscovery/nuclei) + templates | Template-based vulnerability scanning | release | web, vps |
| [interactsh-client](https://github.com/projectdiscovery/interactsh) | Out-of-band interaction catcher (blind SSRF/XXE/RCE) | release | web, api |
| [vulnx](https://github.com/projectdiscovery/vulnx) | CVE search & triage from the terminal | release | web |
| [sqlmap](https://github.com/sqlmapproject/sqlmap) | SQL injection | git / uv | web, api |
| [ghauri](https://github.com/r0oth3x49/ghauri) | SQLi tool that often succeeds where sqlmap struggles | uv | web, api |
| [dalfox](https://github.com/hahwul/dalfox) | XSS scanning & verification | release | web |
| [SSTImap](https://github.com/vladko312/SSTImap) | Server-side template injection | git + venv | web |
| [commix](https://github.com/commixproject/commix) | OS command injection | git + venv | web |
| [smuggler](https://github.com/defparam/smuggler) | HTTP request smuggling (desync) checks | git + venv | opt |

### API, GraphQL & auth

| Tool | What it's for | Method | Default |
|---|---|---|---|
| [jwt_tool](https://github.com/ticarpi/jwt_tool) | JWT analysis, tampering & attacks | git + venv | web, api |
| [graphw00f](https://github.com/dolevf/graphw00f) | GraphQL engine fingerprinting | git + venv | api |
| [clairvoyance](https://github.com/nikitastupin/clairvoyance) | GraphQL schema recovery when introspection is off | uv | api |
| [graphql-cop](https://github.com/dolevf/graphql-cop) | GraphQL security checks | git + venv | api |
| [hurl](https://hurl.dev) | Scriptable HTTP request chains for PoCs & regression tests | release | opt |

### JavaScript, secrets & source

| Tool | What it's for | Method | Default |
|---|---|---|---|
| [jsluice](https://github.com/BishopFox/jsluice) | Extract URLs, paths & secrets from JS | go | web |
| [xnLinkFinder](https://github.com/xnl-h4ck3r/xnLinkFinder) | Endpoint discovery from JS & responses | uv | web |
| [sourcemapper](https://github.com/denandz/sourcemapper) | Rebuild source from exposed `.map` files | go | web |
| [trufflehog](https://github.com/trufflesecurity/trufflehog) | Verified secret scanning | release | web, code |
| [gitleaks](https://github.com/gitleaks/gitleaks) | Fast secret scanning for repos | release | code |
| [Opengrep](https://github.com/opengrep/opengrep) / [Semgrep](https://github.com/semgrep/semgrep) | Pattern-based SAST | release / uv | code |
| [osv-scanner](https://github.com/google/osv-scanner) | Dependency vulnerability scanning (OSV.dev) | release | code |
| [trivy](https://github.com/aquasecurity/trivy) | Container, IaC, filesystem & SBOM scanning | release | code |
| [syft](https://github.com/anchore/syft) + [grype](https://github.com/anchore/grype) | SBOM generation + vulnerability matching | release | code |
| [CodeQL CLI](https://github.com/github/codeql-cli-binaries) | Deep semantic SAST | release | opt |

### Android

| Tool | What it's for | Method | Default |
|---|---|---|---|
| [platform-tools](https://developer.android.com/tools/releases/platform-tools) (`adb`, `fastboot`) | Device access — from Google, not the outdated apt build | official zip | mobile |
| [scrcpy](https://github.com/Genymobile/scrcpy) | Mirror & control the device screen | release / apt | mobile |
| [jadx](https://github.com/skylot/jadx) | DEX → Java decompiler (CLI + GUI) | release | mobile |
| [Droid ASC](https://github.com/MG1937/ASC) (`droidasc`) | On-demand APK search & single-class decompile in milliseconds, tiny RAM; great for huge APKs and AI agents | uv | mobile |
| [rust_ASC](https://github.com/MG1937/rust_ASC) | Rust port of ASC, ~10× faster, also does full-APK decompilation | release (cargo build fallback) | mobile |
| [apktool](https://apktool.org) | Decode, patch & rebuild APKs | official jar + wrapper | mobile |
| [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer) | Zipalign & sign rebuilt APKs | release jar | mobile |
| [frida-tools](https://github.com/frida/frida) | Dynamic instrumentation (Frida 17+) | uv | mobile |
| [objection](https://github.com/sensepost/objection) | Runtime exploration built on Frida | uv | mobile |
| [apk-mitm](https://github.com/niklashigi/apk-mitm) | Auto-patch APKs for TLS interception | npm | mobile |
| [reFlutter](https://github.com/Impact-I/reFlutter) | Flutter app traffic interception & reversing | uv | mobile |
| [blutter](https://github.com/worawit/blutter) | Flutter AOT snapshot analysis | git + build | opt |
| [hermes-dec](https://github.com/P1sec/hermes-dec) | React Native Hermes bytecode decompiler | uv | mobile |
| [apkleaks](https://github.com/dwisiswant0/apkleaks) | Secrets & endpoints in APKs | uv | mobile |
| [medusa](https://github.com/Ch0pin/medusa) | Frida-based modular Android/iOS framework | git + venv | opt |
| [MobSF](https://github.com/MobSF/Mobile-Security-Framework-MobSF) | Automated static/dynamic mobile analysis | docker | mobile |
| [Android cmdline-tools + emulator](https://developer.android.com/studio#command-tools) | Rootable AVDs without Android Studio | official zip | opt |
| [Ghidra](https://github.com/NationalSecurityAgency/ghidra) | Native library (`.so`) reversing | release | mobile |

### iOS (host side)

| Tool | What it's for | Method | Default |
|---|---|---|---|
| [libimobiledevice](https://libimobiledevice.org) | Talk to iOS devices from Linux/macOS | apt / brew | mobile |
| [ipsw](https://github.com/blacktop/ipsw) | Firmware, dyld cache & Mach-O research Swiss-army knife | release | mobile |
| [ipatool](https://github.com/majd/ipatool) | Download IPAs from the App Store | release | mobile |
| [bagbak](https://github.com/ChiChou/bagbak) | Decrypt apps on a jailbroken device | npm | mobile |
| [Grapefruit](https://github.com/ChiChou/grapefruit) | Web UI for iOS runtime analysis | npm | opt |

> iOS testing realistically needs macOS for Xcode signing and a jailbroken or developer-mode test device. On Linux you get device access, IPA handling, Frida/objection and firmware analysis.

### Wordlists & payloads (`~/Wordlists`)

[SecLists](https://github.com/danielmiessler/SecLists), [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings), [Assetnote wordlists](https://wordlists.assetnote.io) (opt-in, large), [OneListForAll](https://github.com/six2dez/OneListForAll), and a resolver list for `puredns`. Large lists are shallow-cloned and shared, never duplicated.

### Everyday CLI

`jq`, `yq`, `gron`, `ripgrep`, `fd`, `bat`, `eza`, `fzf`, `zoxide`, `tmux`, `btop`, `httpie`, `anew`, `unfurl`, `qsreplace`, `uro`.

### AI & MCP (profile `ai`, opt-in)

AI coding CLIs plus MCP servers that let an agent drive your tools: Burp (PortSwigger MCP extension), Caido, Ghidra (GhidraMCP) and Frida. Nothing here stores API keys — you configure credentials yourself.

**Deliberately not included:** tools that are archived, unmaintained for years, or fully superseded (e.g. `tplmap`, `LinkFinder`, `Sublist3r`, `dirb`, `exa`). See [`docs/not-included.md`](docs/not-included.md) for the reasoning; open an issue if you disagree.

---

## Commands

| Command | Does |
|---|---|
| `ait install [--profile P] [--with a,b] [--without c] [--dry-run] [--yes]` | Install tools |
| `ait list [--profile P] [--installed]` | Show the catalog and what's installed |
| `ait doctor [--json]` | Run every tool's health check and print a table |
| `ait update [--tools a,b]` | Update runtimes, pinned tools, nuclei templates & wordlists |
| `ait frida-server [--device SERIAL]` | Download the `frida-server` that matches your host Frida version and device ABI, push it and start it |
| `ait proxy-ca --burp|--caido|--mitmproxy` | Export the proxy CA in the format Android needs (`<hash>.0`) and show install steps |
| `ait wsl-net status\|mirrored\|nat\|toggle` | WSL only: share one IP/localhost between Windows and WSL |
| `ait uninstall [--tools a,b]` | Remove only what AutoInstallTools installed |

Logs: `~/.local/share/ait/logs/`. Failed tools from the last run: `~/.local/share/ait/state/failed-tools`.

---

## GUI tools on WSL2

GUI apps installed by AutoInstallTools (Caido desktop, Burp, jadx-gui, Ghidra, scrcpy) open as normal Windows windows through **WSLg**. You need Windows 11, or Windows 10 22H2 with the Microsoft Store version of WSL. Check with `wsl --version` in PowerShell; if `WSLg version` is listed, you're set. Run `wsl --update` if not.

Tips:
- Launch from the WSL terminal (`caido &`, `jadx-gui &`, `ghidraRun &`). Windows Start-menu shortcuts are created automatically for apps that ship a `.desktop` file.
- A proxy listening in WSL (e.g. `127.0.0.1:8080`) is reachable from your Windows browser at `localhost:8080` thanks to WSL localhost forwarding.
- For Caido, a lighter option is `caido-cli` in WSL and the Caido UI in your Windows browser — no WSLg needed.
- If fonts look blurry on a HiDPI screen, set `GDK_SCALE=2` (GTK apps) or `-Dsun.java2d.uiScale=2` (Java apps like Burp, jadx-gui, Ghidra). `ait doctor` reports whether WSLg is available.

### Share one IP between Windows and WSL (mirrored networking)

With mirrored networking, `localhost` is the same on Windows and WSL: an agent in WSL can reach Burp's or Ghidra's MCP server on Windows, and Windows apps can reach proxies in WSL. Requires Windows 11 22H2 or newer.

```bash
ait wsl-net status      # show current and configured mode
ait wsl-net toggle      # switch between mirrored and NAT
```

It's also in the main menu on WSL as **WSL networking: Mirrored [ON/OFF]**. AutoInstallTools backs up your `.wslconfig`, changes only the `networkingMode` setting, and tells you to run `wsl --shutdown` from PowerShell to apply it.

### Windows-side GUI tools

For daily-driver GUI tools (Burp, Caido), native Windows is smoother than WSLg. Run the companion script in PowerShell:

```powershell
.\windows\ait-windows.ps1                       # pick tools to install via winget
.\windows\ait-windows.ps1 -WslNetwork Mirrored  # same networking toggle from Windows
```

## Mobile testing on WSL2

WSL2 cannot see USB devices by default. Two options:

1. **usbipd-win (recommended):** on Windows, `winget install usbipd`, then `usbipd bind --busid <id>` and `usbipd attach --wsl --busid <id>`. `adb devices` in WSL now sees the phone.
2. **adb over network:** enable wireless debugging on the device and `adb connect <ip>:<port>`.

`ait doctor` detects WSL and tells you which one is configured.

---

## Using a VPS for heavy recon

`--profile vps` installs a headless recon stack, raises file-descriptor limits, ships a `tmux` config and skips everything GUI. Run long jobs there and sync results back to your workstation with `rsync` or your note-taking setup.

---

## Updating

```bash
ait update                 # everything
ait update --tools nuclei  # one tool
```

Pinned versions live in `catalog/tools.yaml`. A scheduled CI job opens a PR when upstream releases a new version, so updates are reviewed rather than blind.

---

## Adding a tool

Add an entry to `catalog/tools.yaml`:

```yaml
- name: x8
  description: Hidden parameter discovery
  tags: [web, api]
  method: github_release
  repo: Sh1Yo/x8
  version: v4.3.0
  asset: { linux_amd64: "x86_64-linux-x8.gz", linux_arm64: "aarch64-linux-x8.gz" }
  check: x8 --version
```

Then run `./ait install --with x8` and `make test`. See [CONTRIBUTING.md](CONTRIBUTING.md) for the inclusion criteria and supported install methods (`apt`, `brew`, `github_release`, `go`, `uv`, `npm`, `cargo`, `git_venv`, `docker`, `official_archive`, `manual`).

---

## Safety & supply chain

- Release downloads are pinned and verified against SHA-256 checksums from the catalog or the upstream checksum file.
- No `curl | bash` from third parties. NodeSource/Go/Docker repos are added with signed keys.
- No credentials, targets or scan configs are ever stored.
- `sudo` is used only for system packages; everything else runs as your user.
- `--dry-run` prints every command without executing anything.

---

## FAQ

**Will it break my existing setup?** Tools you already have are detected and skipped. Shell changes go in a single, clearly marked block in your rc file and are removed by `ait uninstall`.

**Why not just use Kali?** Kali is great. Many testers work on Ubuntu, WSL or macOS though, and Kali's packages for some fast-moving tools lag behind upstream. On Kali, this repo uses Kali packages where they're current.

**Why isn't X installed?** Check `docs/not-included.md`, then open an issue with the tool, why it's better than what's here, and its maintenance status.

---

## Contributing

PRs welcome — new tools, platform support, fixes. Please read [CONTRIBUTING.md](CONTRIBUTING.md). All PRs must pass `shellcheck`, `bats` tests and the CI install matrix.

## License

MIT — see [LICENSE](LICENSE). Each installed tool keeps its own license.
````
