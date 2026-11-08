<div align="center">

# AutoInstallTools

**A catalog-driven installer for web and mobile AppSec workstations on Linux and WSL2.**

Curated tools only. Pinned and checksum-verified. Safe to re-run. Easy to remove.

[![CI](https://github.com/ZyperX/AutoInstallTools/actions/workflows/ci.yml/badge.svg)](https://github.com/ZyperX/AutoInstallTools/actions/workflows/ci.yml)
![Platforms](https://img.shields.io/badge/platform-Linux%20%7C%20WSL2-blue)
![Shell](https://img.shields.io/badge/shell-bash%205%2B-green)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

</div>

---

> ### Project status — pre-v1
>
> The Linux/WSL workstation flow is implemented. Local ShellCheck/Bats tests and
> the Ubuntu Docker integration smoke check have passed. The project is still
> pre-v1; review the catalog and run `ait install --profile ... --dry-run`
> before installing tools on a workstation.
>
> ```bash
> ./ait                                  # interactive menu
> ./ait list [--profile web] [--category android]
> ./ait install --profile web --dry-run  # resolve & preview (installs nothing)
> ./ait install --profile mobile --with ghidra --without amass
> ./ait frida-server --device emulator-5554   # match host Frida to device ABI
> ./ait proxy-ca --burp ~/Downloads/cacert.der
> ./ait wsl-net status                    # WSL2 only
> ./ait doctor | ./ait update | ./ait uninstall
> ```
>
> The catalog ([`catalog/tools.yaml`](catalog/tools.yaml)) is the source of truth,
> parsed with a pinned, checksum-verified `yq`; profiles (`minimal`, `web`, `api`,
> `mobile`, `code`, `vps`, `all`, `ai`) resolve by tag with `--with`/`--without`.
> Pinned release binaries are verified before extraction, and `--dry-run` does
> not install tools or persist installer state. The original
> `./install.sh [--minimal|--full|--mobile]` bootstrap still works too.
>
> The CLI, catalog, interactive menu, mobile helpers, WSL networking support,
> and optional Windows companion are implemented. Ubuntu on Linux/WSL2 is the
> primary use case. Other distributions and macOS support are not part of the
> project's current validation target. The project has not made a v1 release.

---

## Why this exists

Every new laptop, VM, WSL distro or VPS costs a pentester half a day: hunting the right `go install` path, discovering apt ships a three-year-old `apktool`, matching `frida-server` to the device, fixing `PATH`. AutoInstallTools turns that into one command and a coffee.

What makes it different from the hundred other "install-all-the-tools" scripts:

- **Curated, not hoarded.** Every tool earns its place. Abandoned or superseded tools are left out or marked as such (e.g. `tplmap` → `SSTImap`, `hakrawler` → `katana`, `cvemap` → `vulnx`).
- **Declarative catalog.** All tools live in [`catalog/tools.yaml`](catalog/tools.yaml): one entry per tool with its install method, version, profile and a health check. Adding a tool is a 6-line PR.
- **Verified installs.** Release binaries are pinned and SHA-256 checked. `ait update` bumps pins deliberately, not silently.
- **User-space first.** Most tools land in `~/.local`, `~/go/bin` and `~/.local/share/ait`. `sudo` is used only where system packages or repository configuration require it.
- **Idempotent and recoverable.** Re-run as often as you like. A failed tool does not stop the remaining installs; failures are summarized with a retry command and the overall command returns non-zero.
- **Mobile is a first-class citizen.** Correct `platform-tools`, `jadx`, `apktool`, Frida 17-compatible tooling, an `ait frida-server` helper that pushes the right build to your device, and honest notes for iOS from Linux.

> ⚠️ **Authorized use only.** These tools are for systems you own or have written permission to test. You are responsible for how you use them.

---

## Quick start

### Requirements

- Ubuntu 22.04 or newer, either on Linux or under WSL2. Other Debian-family
  systems may work, but are outside the primary validation target.
- Bash 5+, `curl`, and `sudo` for system packages. `git`, `jq`, and `ca-certificates`
  are installed as needed by the selected tools.
- An internet connection to the configured package repositories and upstream
  release hosts.
- For Android device work: an Android device or emulator, Android debugging
  enabled, and `adb` connectivity. WSL users may need USB forwarding; see
  [Mobile testing on WSL2](#mobile-testing-on-wsl2).

AutoInstallTools places user-managed tools in `~/.local` and its state in
`~/.local/share/ait`. `sudo` is used for system packages. Some catalog entries
are opt-in, require a separate license choice, or need manual setup; inspect
the dry-run and tool notes before proceeding.

```bash
git clone https://github.com/ZyperX/AutoInstallTools.git
cd AutoInstallTools
./ait install --profile web --dry-run  # review the planned changes first
./ait install --profile web            # install the web testing profile
./ait                                   # open the interactive menu
```

The installer may ask for your password when a selected tool requires an apt
package. It attempts all selected tools, then reports failures and a retry
command. A failed install makes the command return non-zero.

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

**All tools** installs everything (after one confirmation). **Update existing** updates tools recorded in the AutoInstallTools manifest and refreshes Nuclei templates when Nuclei is available.

What each menu covers:

| Menu choice | Catalog tags included |
|---|---|
| Mobile AppSec | `mobile` (Android + iOS host tooling, Frida stack, decompilers; MobSF is opt-in) |
| Web AppSec | `web`, `api`, `code` (proxies, recon, fuzzing, injection, API/GraphQL/JWT, JS & secrets, SAST/SCA) |
| All tools | everything except opt-in extras |

The menu works over SSH and in WSL. If `whiptail` isn't available it falls back to a numbered text prompt.

### Non-interactive (scripts, CI, VPS)

```bash
./ait install --profile web           # web AppSec workstation
./ait install --profile mobile        # Android + iOS host tooling
./ait install --profile all            # web + mobile + API + code review
./ait install --profile vps           # headless recon box (no GUI apps)
./ait install --profile web --with ghidra,codeql --without amass
./ait install --profile all --dry-run   # show exactly what would happen
./ait install --profile mobile --yes --no-shell # non-interactive, skip shell edits
```

After installation, open a new shell (or reload your current one) and check
the managed tools:

```bash
exec $SHELL          # reload PATH
ait doctor           # verify everything works
```

---

## Supported platforms

| Platform | Status | Notes |
|---|---|---|
| Ubuntu 22.04+ | Primary | Linux and WSL2 are the main target |
| WSL2 with Ubuntu | Supported | WSLg GUI support and WSL networking helpers are documented below |
| Debian 12 / Kali Linux | Best effort | Platform-specific package choices are present; not part of the current validation target |
| macOS | Out of scope | Some Homebrew code exists, but macOS is not a supported target |
| Arch / Fedora | Not supported | Package and installer mappings are not provided |

Release catalog entries commonly support `x86_64` and `arm64` (`aarch64`).
Availability depends on each upstream project's published assets.

---

## Profiles

Profiles are bundles of catalog tags. Combine them, or fine-tune with `--with` / `--without`.

| Profile | For | Includes |
|---|---|---|
| `minimal` | Base workstation | Core CLI utilities and language runtimes |
| `web` | Web & API testing | minimal + proxies, recon, discovery, fuzzing, injection, auth, secrets, wordlists |
| `api` | API-focused engagements | minimal + API/GraphQL/JWT tooling and discovery |
| `mobile` | Android & iOS host tooling | minimal + Android SDK tools, decompilers, Frida stack, and iOS host tools |
| `code` | Source review / SAST / SCA | minimal + Opengrep/Semgrep, secrets scanners, SBOM & dependency scanners |
| `vps` | Headless recon server | minimal + recon + nuclei, no GUI apps, tuned for long runs in `tmux` |
| `ai` | Agent-assisted development | Opt-in AI coding CLIs; MCP server setup is not automated |
| `all` | Broad workstation | core, runtimes, recon, web, API, code, mobile, cloud, and wordlists; excludes opt-in tools |

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

### AI tooling (profile `ai`, opt-in)

Optional AI coding CLIs are available through the `ai` profile. MCP server
installation and credentials are not managed by this project; configure those
separately if you use them. AutoInstallTools does not store API keys.

**Deliberately not included:** tools that are archived, unmaintained for years, or fully superseded (e.g. `tplmap`, `LinkFinder`, `Sublist3r`, `dirb`, `exa`). See [`docs/not-included.md`](docs/not-included.md) for the reasoning; open an issue if you disagree.

---

## Commands

| Command | Does |
|---|---|
| `ait install --profile P [--with a,b] [--without c] [--dry-run] [--yes] [--no-shell]` | Install a profile; add/remove tools or tags; preview or skip prompts/shell setup |
| `ait list [--profile P] [--category C] [--installed] [--json]` | Show the catalog and what's installed |
| `ait doctor [--json]` | Run every tool's health check and print a table |
| `ait update [--tools a,b] [--dry-run]` | Update managed tools; also update nuclei templates when available |
| `ait frida-server [--device SERIAL]` | Download the `frida-server` that matches your host Frida version and device ABI, push it and start it |
| `ait proxy-ca --burp\|--caido\|--mitmproxy [CERT]` | Convert a proxy CA to Android's `<hash>.0` format and show installation steps |
| `ait wsl-net status\|mirrored\|nat\|toggle` | WSL2 only: inspect or change the configured networking mode |
| `ait uninstall --tools a,b [--apt] [--dry-run]` | Remove selected manifest-managed tools; apt packages need `--apt` |
| `ait uninstall --all [--apt] [--dry-run]` | Remove all manifest-managed tools |

`--with` and `--without` accept comma-separated tool names or catalog tags.
`--yes` suppresses interactive confirmation; use it only when you have reviewed
the selected tools. `--dry-run` previews supported install/update/uninstall
actions without performing the requested changes.

The manifest is stored at `~/.local/share/ait/state/manifest.tsv`. Only items
recorded there are considered by uninstall. Apt packages are left installed
unless `--apt` is provided. Tool-specific data and dependencies may require
separate cleanup.

Logs: `~/.local/share/ait/logs/`. Failed tools from the last run: `~/.local/share/ait/state/failed-tools`.

---

## GUI tools on WSL2

GUI apps installed by AutoInstallTools (Caido desktop, Burp, jadx-gui, Ghidra, scrcpy) open as normal Windows windows through **WSLg**. You need Windows 11, or Windows 10 22H2 with the Microsoft Store version of WSL. Check with `wsl --version` in PowerShell; if `WSLg version` is listed, you're set. Run `wsl --update` if not.

A full WSL setup guide is in [`docs/wsl-mobile.md`](docs/wsl-mobile.md).

Tips:
- Launch from the WSL terminal (`caido &`, `jadx-gui &`, `ghidraRun &`). `ait install` writes `.desktop` launchers for installed GUI tools to `~/.local/share/applications`, so they also appear in the Windows Start menu.
- A proxy listening in WSL (e.g. `127.0.0.1:8080`) is reachable from your Windows browser at `localhost:8080` thanks to WSL localhost forwarding.
- For Caido, a lighter option is `caido-cli` in WSL and the Caido UI in your Windows browser — no WSLg needed.
- If fonts look blurry on a HiDPI screen, set `GDK_SCALE=2` (GTK apps) or `-Dsun.java2d.uiScale=2` (Java apps like Burp, jadx-gui, Ghidra). `ait doctor` reports whether WSLg is available.

### Share one IP between Windows and WSL (mirrored networking)

With mirrored networking, `localhost` is the same on Windows and WSL: an agent in WSL can reach Burp's or Ghidra's MCP server on Windows, and Windows apps can reach proxies in WSL. Requires Windows 11 22H2 or newer.

```bash
ait wsl-net status      # show current and configured mode
ait wsl-net toggle      # switch between mirrored and NAT
```

It's also in the main menu on WSL as **WSL networking: Mirrored [ON/OFF]**. AutoInstallTools backs up your `.wslconfig`, changes only the `networkingMode` setting (CRLF-safe, preserving comments and other keys), compares the configured mode with the live one, reports "restart pending", and tells you to run `wsl --shutdown` from PowerShell to apply it. See [`docs/wsl-mobile.md`](docs/wsl-mobile.md).

| Command | Does |
|---|---|
| `ait wsl-net status` | Configured mode, live mode and restart-pending state |
| `ait wsl-net mirrored` / `nat` | Write that mode under `[wsl2]` |
| `ait wsl-net toggle` | Flip between mirrored and NAT |
| `ait wsl-net … --dry-run` | Show the `.wslconfig` diff only |

### Windows-side GUI tools

For daily-driver GUI tools (Burp, Caido), native Windows is smoother than WSLg. Run the companion script in PowerShell:

```powershell
.\windows\ait-windows.ps1                       # pick tools to install via winget
.\windows\ait-windows.ps1 -WslNetwork Mirrored  # same networking toggle from Windows
.\windows\ait-windows.ps1 -WslNetwork Nat -SkipTools
```

The checklist covers Burp Suite Community/Professional, jadx, Temurin JDK 21,
scrcpy and Android platform-tools via winget. Caido, Ghidra and rust_ASC are
downloaded from their official release channels because they are not in winget
at the time of writing. `-WslNetwork` uses the same backup and CRLF-safe edit
rules as `ait wsl-net`. The script is linted with PSScriptAnalyzer in CI.

## Mobile testing on WSL2

WSL2 cannot see USB devices by default. Two options:

1. **usbipd-win (recommended):** on Windows, `winget install usbipd`, then `usbipd bind --busid <id>` and `usbipd attach --wsl --busid <id>`. `adb devices` in WSL now sees the phone.
2. **adb over network:** enable wireless debugging on the device and `adb connect <ip>:<port>`.
3. **Reuse Windows' adb server:** with mirrored networking, `export ADB_SERVER_SOCKET=tcp:localhost:5037` lets WSL talk to the adb server already running on Windows.

Only one adb server may own port 5037: run adb in WSL **or** Windows, not both. `ait doctor` reports the connected device state and prints these hints on WSL.

For Frida, `ait frida-server` reads the host `frida --version` and the device ABI (`ro.product.cpu.abi`), downloads the matching `frida-server` release over HTTPS, verifies its sha256 from the GitHub API, pushes it to `/data/local/tmp`, and confirms it with `frida-ps`. Use `--device SERIAL` when more than one device is attached. Catalog pins `frida-tools` 14.13.0 with `objection` 1.12.5 so the Frida 17 host tooling stays compatible.

`ait proxy-ca --burp|--caido|--mitmproxy [CERT]` converts a PEM or DER export to `<subject_hash_old>.0`, the filename Android expects, and prints both the user-store and system-store (including Android 14+ APEX `conscrypt` cacerts) steps.

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
tools:
  - name: x8
    desc: Hidden parameter discovery
    category: discovery
    tags: [web, api]
    method: github_release
    repo: Sh1Yo/x8
    version: v4.3.0
    asset: { linux_amd64: "x86_64-linux-x8.gz", linux_arm64: "aarch64-linux-x8.gz" }
    sha256: { linux_amd64: "<verified-sha256>", linux_arm64: "<verified-sha256>" }
    check: x8 --version
```

Then preview it with `./ait install --profile web --with x8 --dry-run`, and run
`make lint`, `make test`, and `make integration` for the Linux/WSL path. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) for inclusion criteria and supported
install methods (`apt`, `brew`, `github_release`, `go`, `uv`, `npm`, `cargo`,
`git_venv`, `docker`, `official_archive`, `manual`).

---

## Safety & supply chain

- Release downloads are pinned and verified against SHA-256 checksums from the catalog or the upstream checksum file.
- Release archives are rejected when required checksum data is missing or does
  not match. Catalog entries that install from package indexes or source control
  follow those upstream trust models instead.
- Review the catalog entry and dry-run before installing a large profile. Some
  tools can download templates, wordlists, containers, or additional runtimes.
- No credentials, targets or scan configs are ever stored.
- `sudo` is used only for system packages; everything else runs as your user.
- `--dry-run` does not install selected tools or persist installer state.

---

## FAQ

**Will it break my existing setup?** Tools you already have are detected and skipped. Shell changes go in a single, clearly marked block in your rc file and are removed by `ait uninstall`.

**Why not just use Kali?** Kali is a good option. AutoInstallTools targets an
Ubuntu/WSL workflow and uses upstream releases for many fast-moving tools.

**Why isn't X installed?** Check `docs/not-included.md`, then open an issue with the tool, why it's better than what's here, and its maintenance status.

---

## Contributing

PRs welcome — new tools, Linux/WSL fixes, and documentation. Please read
[`CONTRIBUTING.md`](CONTRIBUTING.md). Before submitting, run `make lint`,
`make test`, and `make integration` where Docker is available. The GitHub
workflow may also run checks outside the Linux/WSL target scope.

## License

MIT — see [LICENSE](LICENSE). Each installed tool keeps its own license.
