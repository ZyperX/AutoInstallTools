<div align="center">

# AutoInstallTools

**A catalog-driven installer for web and mobile AppSec workstations on Linux, WSL2 and macOS (beta).**

Curated tools only. Pinned and checksum-verified. Safe to re-run. Easy to remove.

[![CI](https://github.com/ZyperX/AutoInstallTools/actions/workflows/ci.yml/badge.svg)](https://github.com/ZyperX/AutoInstallTools/actions/workflows/ci.yml)
![Platforms](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian%20%7C%20Kali%20%7C%20WSL2%20%7C%20macOS-blue)
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
> primary use case; Debian 12 and Kali are supported and covered by the CI
> matrix. macOS is a Homebrew-based beta: Bash 5 and Homebrew are required, and
> tools without a macOS mapping are skipped. Arch and Fedora are not supported
> yet. The project has not made a v1 release.

## Demo

![AutoInstallTools demo](docs/demo.gif)

`ait install --profile web --dry-run` resolves a profile and previews the
planned changes without installing anything. The recording is generated from
[`docs/demo.tape`](docs/demo.tape) with [vhs](https://github.com/charmbracelet/vhs).

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

- Ubuntu 22.04 or newer on Linux or WSL2 (primary). Debian 12 and Kali Linux
  are supported and covered by CI.
- macOS 13+ is a **beta** target: install Bash 5+ and Homebrew, then use
  `./ait` (the legacy `./install.sh` bootstrap stays Linux-only).
- Bash 5+, `curl`, and either `sudo` (Linux) or Homebrew (macOS) for system
  packages. `git`, `jq`, and `ca-certificates` are installed as needed by the
  selected tools.
- An internet connection to the configured package repositories and upstream
  release hosts.
- For Android device work: an Android device or emulator, Android debugging
  enabled, and `adb` connectivity. WSL users may need USB forwarding; see
  [Mobile testing on WSL2](#mobile-testing-on-wsl2).

AutoInstallTools places user-managed tools in `~/.local` and its state in
`~/.local/share/ait`. `sudo` is used for system packages on Linux; Homebrew is
used on macOS. Some catalog entries are opt-in, require a separate license
choice, or need manual setup; inspect the dry-run and tool notes before
proceeding.

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
│  1  Install core utilities & runtimes    │
│  2  Install Web AppSec tools             │
│  3  Install API testing tools            │
│  4  Install Mobile AppSec tools          │
│  5  Install source-review (SAST/SCA)     │
│  6  Install headless recon server tools  │
│  7  Install AI coding assistants         │
│  8  Install All tools                    │
│  9  Update existing tools                │
└──────────────────────────────────────────┘
```

Choosing a profile asks how you want to install:

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
| Core utilities & runtimes | `core`, `runtime` |
| Web AppSec | `web`, `api`, `code` (proxies, recon, fuzzing, injection, API/GraphQL/JWT, JS & secrets, SAST/SCA) |
| API testing | `api` (GraphQL, JWT, auth and API discovery) |
| Mobile AppSec | `mobile` (Android + iOS host tooling, Frida stack, decompilers; MobSF is opt-in) |
| Source review (SAST/SCA) | `code` (Semgrep/Opengrep, secrets and SBOM/dependency scanners) |
| Headless recon server | `recon` + `wordlists` (no GUI tools; tuned for `tmux` and long runs) |
| AI coding assistants | `ai` (opt-in profile; never part of All tools) |
| All tools | everything except opt-in extras and the `ai` profile |

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
| Ubuntu 22.04 / 24.04 | Primary | Linux and WSL2 are the main target; CI runs both |
| Debian 12 | Supported | CI runs the web and mobile profiles |
| Kali Linux | Supported | Prefers Kali packages when they are at least the pinned version; CI runs the web and mobile profiles |
| WSL2 | Supported | WSLg GUI support and WSL networking helpers are documented below |
| macOS | Beta | Homebrew-based; Bash 5 and Homebrew required; Linux-only tools without a mapping are skipped |
| Arch / Fedora | Not supported | Package and installer mappings are not provided |

Release catalog entries commonly support `x86_64` and `arm64` (`aarch64`).
Availability depends on each upstream project's published assets. See
[`docs/platforms.md`](docs/platforms.md) for mapping fields, detection and the
macOS beta rules.

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

Every tool below is defined in [`catalog/tools.yaml`](catalog/tools.yaml).
The tables are generated by `scripts/gen-readme.sh`; edit the catalog, then run
`scripts/gen-readme.sh --write`.

<!-- catalog:start -->
> Generated from `catalog/tools.yaml` by `scripts/gen-readme.sh`; do not edit by hand.
> **Method** is how a tool is installed; **Default** lists profiles that select it (`opt` = only via `--with`).

### Core & everyday CLI

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [eza](https://github.com/eza-community/eza) | Modern ls replacement | release | minimal, mobile, web, api, code, vps, all |
| [uro](https://pypi.org/project/uro/) | Deduplicate URLs from a list | uv | minimal, mobile, web, api, code, vps, all |
| [yq](https://github.com/mikefarah/yq) | YAML/JSON/XML processor (mikefarah) | release | minimal, mobile, web, api, code, vps, all |
| `base-essentials` | Base system packages & build toolchain | apt | minimal, mobile, web, api, code, vps, all |
| `bat` | cat with syntax highlighting | apt | minimal, mobile, web, api, code, vps, all |
| `btop` | Resource monitor (TUI) | apt | minimal, mobile, web, api, code, vps, all |
| `curl` | Transfer data over HTTP and more | apt | minimal, mobile, web, api, code, vps, all |
| `fd` | Fast, friendly file finder | apt | minimal, mobile, web, api, code, vps, all |
| `fzf` | Fuzzy finder for the terminal | apt | minimal, mobile, web, api, code, vps, all |
| `git` | Distributed version control | apt | minimal, mobile, web, api, code, vps, all |
| `gron` | Make JSON greppable | go | minimal, mobile, web, api, code, vps, all |
| `httpie` | Human-friendly HTTP client | apt | minimal, mobile, web, api, code, vps, all |
| `jq` | Command-line JSON processor | apt | minimal, mobile, web, api, code, vps, all |
| `ncdu` | Disk usage analyzer (TUI) | apt | minimal, mobile, web, api, code, vps, all |
| `ripgrep` | Fast recursive grep | apt | minimal, mobile, web, api, code, vps, all |
| `socat` | Multipurpose relay / socket tool | apt | minimal, mobile, web, api, code, vps, all |
| `tmux` | Terminal multiplexer | apt | minimal, mobile, web, api, code, vps, all |
| `tree` | List directories as a tree | apt | minimal, mobile, web, api, code, vps, all |
| `whiptail` | Dialog boxes for shell scripts | apt | minimal, mobile, web, api, code, vps, all |
| `zoxide` | Smarter cd that learns your habits | apt | minimal, mobile, web, api, code, vps, all |

### Runtimes

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [pnpm](https://www.npmjs.com/package/pnpm) | Fast, disk-efficient npm alternative | npm | minimal, mobile, web, api, code, vps, all |
| `go` | Go toolchain (official tarball) | runtime | minimal, mobile, web, api, code, vps, all |
| `jdk` | JDK 21 with Maven and Gradle | runtime | minimal, mobile, web, api, code, vps, all |
| `node` | Node.js 22 LTS (NodeSource) | runtime | minimal, mobile, web, api, code, vps, all |
| `python` | Python 3 with pip and pipx | apt | minimal, mobile, web, api, code, vps, all |
| `rust` | Rust toolchain via rustup | runtime | minimal, mobile, web, api, code, vps, all |
| `uv` | Fast Python package & tool manager | runtime | minimal, mobile, web, api, code, vps, all |

### Recon & attack-surface mapping

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [amass](https://github.com/owasp-amass/amass) | Deep OSINT subdomain enumeration | release | opt |
| [asnmap](https://github.com/projectdiscovery/asnmap) | Map ASN to IP ranges | release | web, vps, all |
| [cdncheck](https://github.com/projectdiscovery/cdncheck) | Detect CDN/WAF/cloud by IP | release | web, vps, all |
| [gowitness](https://github.com/sensepost/gowitness) | Screenshot & triage many hosts | release | web, vps, all |
| [rustscan](https://crates.io/crates/rustscan) | Very fast port discovery | cargo | web, vps, all |
| [tlsx](https://github.com/projectdiscovery/tlsx) | TLS data collection & analysis | release | web, vps, all |
| [urlfinder](https://github.com/projectdiscovery/urlfinder) | Passive URL discovery | release | web, vps, all |
| [waymore](https://pypi.org/project/waymore/) | More URLs from Wayback & more sources | uv | web, vps, all |
| `alterx` | Subdomain permutation generator | go | web, vps, all |
| `anew` | Append only new lines to a file | go | web, vps, all |
| `assetfinder` | Find domains related to a target | go | opt |
| `dnsx` | Fast DNS resolution & probing | go | web, vps, all |
| `gau` | Fetch known URLs from passive sources | go | web, vps, all |
| `hakrawler` | Fast web crawler for endpoints | go | opt |
| `httpx` | HTTP probing & tech detection | go | web, vps, all |
| `katana` | Fast crawler with JS parsing | go | web, vps, all |
| `mapcidr` | CIDR/IP range manipulation | go | web, vps, all |
| `naabu` | Fast SYN/CONNECT port scanner | go | web, vps, all |
| `nmap` | Network & service scanner | apt | minimal, mobile, web, api, code, vps, all |
| `puredns` | Wildcard-aware DNS brute & resolve | go | web, vps, all |
| `qsreplace` | Replace query-string values in URLs | go | web, vps, all |
| `shuffledns` | massdns wrapper for DNS brute force | go | web, vps, all |
| `subfinder` | Passive subdomain enumeration | go | web, vps, all |
| `uncover` | Query Shodan/Censys/FOFA from CLI | go | web, vps, all |
| `unfurl` | Pull parts out of URLs | go | web, vps, all |
| `waybackurls` | Fetch URLs from the Wayback Machine | go | opt |

### Intercepting proxies

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [mitmproxy](https://pypi.org/project/mitmproxy/) | Scriptable intercepting proxy | uv | mobile, web, all |
| [zap](https://github.com/zaproxy/zaproxy) | OWASP ZAP proxy & DAST scanner | official archive | opt |
| `burp` | Industry-standard web proxy (GUI) | manual | opt |
| `caido-cli` | Modern web proxy CLI (headless) | official archive | mobile, web, all |
| `caido-desktop` | Modern web proxy desktop UI | official archive | mobile, web, all |

### Content discovery & fuzzing

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [arjun](https://pypi.org/project/arjun/) | HTTP parameter discovery | uv | web, api, all |
| [dirsearch](https://pypi.org/project/dirsearch/) | Web path brute forcer | uv | opt |
| [feroxbuster](https://github.com/epi052/feroxbuster) | Recursive content discovery | release | web, all |
| [nomore403](https://github.com/devploit/nomore403) | 401/403 bypass techniques | release | web, all |
| [x8](https://github.com/Sh1Yo/x8) | Hidden HTTP parameter discovery | release | web, api, all |
| `ffuf` | The general-purpose web fuzzer | go | web, api, all |
| `gobuster` | Directory/DNS/vhost brute forcing | apt | opt |

### Vulnerability scanning & exploitation

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [commix](https://github.com/commixproject/commix) | OS command injection | git + venv | web, all |
| [ghauri](https://github.com/r0oth3x49/ghauri) | SQLi tool, strong where sqlmap fails | git + venv | web, api, all |
| [interactsh-client](https://github.com/projectdiscovery/interactsh) | Out-of-band interaction catcher | release | web, api, all |
| [smuggler](https://github.com/defparam/smuggler) | HTTP request smuggling checks | git + venv | opt |
| [sstimap](https://github.com/vladko312/SSTImap) | Server-side template injection | git + venv | web, all |
| [vulnx](https://github.com/projectdiscovery/vulnx) | CVE search & triage from the terminal | release | web, all |
| `dalfox` | XSS scanning & verification | go | web, all |
| `nuclei` | Template-based vulnerability scanner | go | web, vps, all |
| `sqlmap` | Automatic SQL injection testing | apt | web, api, all |

### API, GraphQL & auth

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [clairvoyance](https://pypi.org/project/clairvoyance/) | GraphQL schema recovery | uv | web, api, all |
| [graphql-cop](https://github.com/dolevf/graphql-cop) | GraphQL security checks | git + venv | web, api, all |
| [graphw00f](https://github.com/dolevf/graphw00f) | GraphQL engine fingerprinting | git + venv | web, api, all |
| [hurl](https://github.com/Orange-OpenSource/hurl) | Scriptable HTTP request chains | release | opt |
| [jwt_tool](https://github.com/ticarpi/jwt_tool) | JWT analysis, tampering & attacks | git + venv | web, api, all |
| [kiterunner](https://github.com/assetnote/kiterunner) | API route discovery with real lists | release | web, api, all |

### JavaScript, secrets & source

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [gitleaks](https://github.com/gitleaks/gitleaks) | Fast secret scanning for repos | release | web, code, all |
| [trufflehog](https://github.com/trufflesecurity/trufflehog) | Verified secret scanning | release | web, code, all |
| [xnlinkfinder](https://pypi.org/project/xnLinkFinder/) | Endpoint discovery from JS & responses | uv | web, all |
| `jsluice` | Extract URLs & secrets from JS | go | web, all |
| `sourcemapper` | Rebuild source from exposed source maps | go | web, all |

### SAST & SCA

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [codeql](https://github.com/github/codeql-cli-binaries) | Deep semantic code analysis (CodeQL CLI) | official archive | opt |
| [grype](https://github.com/anchore/grype) | Vulnerability matching from SBOMs | release | web, code, all |
| [opengrep](https://github.com/opengrep/opengrep) | Pattern-based static analysis (SAST) | official archive | web, code, all |
| [osv-scanner](https://github.com/google/osv-scanner) | Dependency vulnerability scanning | release | web, code, all |
| [semgrep](https://pypi.org/project/semgrep/) | Lightweight multi-language SAST | uv | opt |
| [syft](https://github.com/anchore/syft) | Generate SBOMs from images & dirs | release | web, code, all |
| [trivy](https://github.com/aquasecurity/trivy) | Container/IaC/FS & SBOM scanner | release | web, code, all |

### Android

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [apk-mitm](https://www.npmjs.com/package/apk-mitm) | Auto-patch APKs for TLS interception | npm | mobile, all |
| [apkleaks](https://pypi.org/project/apkleaks/) | Secrets & endpoints in APKs | uv | mobile, all |
| [apktool](https://github.com/iBotPeaches/Apktool) | Decode, patch & rebuild APKs | official archive | mobile, all |
| [droidasc](https://pypi.org/project/droidasc/) | Fast on-demand APK search & decompile | uv | mobile, all |
| [frida-tools](https://pypi.org/project/frida-tools/) | Dynamic instrumentation (Frida 17+) | uv | mobile, all |
| [hermes-dec](https://pypi.org/project/hermes-dec/) | React Native Hermes decompiler | uv | mobile, all |
| [jadx-gui](https://github.com/skylot/jadx) | DEX to Java decompiler (GUI) | official archive | mobile, all |
| [jadx](https://github.com/skylot/jadx) | DEX to Java decompiler (CLI) | official archive | mobile, all |
| [medusa](https://github.com/Ch0pin/medusa) | Modular Frida mobile testing framework | git + venv | opt |
| [objection](https://pypi.org/project/objection/) | Runtime mobile exploration on Frida | uv | mobile, all |
| [reflutter](https://pypi.org/project/reflutter/) | Flutter app traffic interception | uv | mobile, all |
| [rust-asc](https://github.com/MG1937/rust_ASC) | Rust ASC, 10x faster full decompile | release | mobile, all |
| [scrcpy](https://github.com/Genymobile/scrcpy) | Mirror & control the device screen | official archive | mobile, all |
| [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer) | Zipalign & sign rebuilt APKs | official archive | mobile, all |
| `android-cmdline-tools` | Android SDK tools & emulator | official archive | opt |
| `android-platform-tools` | Android adb & fastboot (upstream) | official archive | mobile, all |
| `blutter` | Flutter AOT snapshot analysis | manual | opt |
| `mobsf` | Static/dynamic mobile analysis suite | docker | opt |

### iOS (host side)

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [bagbak](https://www.npmjs.com/package/bagbak) | Decrypt apps on a jailbroken device | npm | mobile, all |
| [grapefruit](https://www.npmjs.com/package/grapefruit) | Web UI for iOS runtime analysis | npm | opt |
| [ipatool](https://github.com/majd/ipatool) | Download IPAs from the App Store | release | mobile, all |
| [ipsw](https://github.com/blacktop/ipsw) | Firmware & Mach-O research toolkit | release | mobile, all |
| `libimobiledevice` | Talk to iOS devices from Linux | apt | mobile, all |

### Reverse engineering

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [ghidra](https://github.com/NationalSecurityAgency/ghidra) | Software reverse engineering suite | official archive | opt |

### Wordlists & payloads

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [fuzzdb](https://github.com/fuzzdb-project/fuzzdb) | Attack patterns & discovery lists | git | web, vps, all |
| [onelistforall](https://github.com/six2dez/OneListForAll) | Merged content-discovery wordlist | git | web, vps, all |
| [payloadsallthethings](https://github.com/swisskyrepo/PayloadsAllTheThings) | Payloads & bypasses for web testing | git | web, vps, all |
| [resolvers](https://github.com/trickest/resolvers) | Trusted public DNS resolver list | git | web, vps, all |
| [seclists](https://github.com/danielmiessler/SecLists) | The security tester's wordlists | git | web, vps, all |
| `assetnote` | Assetnote wordlists (large CDN mirror) | mirror | opt |

### Cloud & Kubernetes

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [k9s](https://github.com/derailed/k9s) | Kubernetes cluster TUI | release | all |
| [kubectx](https://github.com/ahmetb/kubectx) | Switch kube contexts & namespaces | release | all |
| `awscli` | AWS CLI v2 (official installer) | runtime | all |

### Containers

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [dive](https://github.com/wagoodman/dive) | Inspect Docker image layers | release | all |
| [docker-compose](https://github.com/docker/compose) | Compose v2 Docker CLI plugin | release | all |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | Docker management TUI | release | all |
| `docker` | Container engine (docker.io) | apt | all |

### AI assistants

| Tool | What it is for | Method | Default |
|---|---|---|---|
| [aider](https://pypi.org/project/aider-chat/) | AI pair programming in your terminal | uv | ai |
| [claude-code](https://www.npmjs.com/package/@anthropic-ai/claude-code) | Anthropic Claude Code CLI | npm | ai |
| [llm](https://pypi.org/project/llm/) | CLI for large language models | uv | ai |
| [opencode](https://www.npmjs.com/package/opencode-ai) | Open-source AI coding agent CLI | npm | ai |
| [shell-gpt](https://pypi.org/project/shell-gpt/) | LLM helper for the command line | uv | opt |

<!-- catalog:end -->

> iOS testing realistically needs macOS for Xcode signing and a jailbroken or developer-mode test device. On Linux you get device access, IPA handling, Frida/objection and firmware analysis.
>
> Wordlists land in `~/Wordlists`: SecLists, PayloadsAllTheThings, Assetnote (opt-in, large), OneListForAll and a resolver list for `puredns`. Large lists are shallow-cloned and shared, never duplicated.
>
> Optional AI coding CLIs are available through the `ai` profile. MCP server installation and credentials are not managed by this project; configure those separately if you use them. AutoInstallTools does not store API keys.

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
`make lint`, `make test`, and `./scripts/gen-readme.sh --write`. See
[`docs/adding-tools.md`](docs/adding-tools.md) for inclusion criteria, platform
mappings, pinning, and the full list of install methods.

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

**Why not just use Kali?** Kali is supported. AutoInstallTools uses Kali's
packages when they are at least the pinned upstream version and falls back to
pinned upstream releases for fast-moving tools. Ubuntu/WSL remains the primary
development and CI target.

**Does it work on macOS?** Yes, as a beta. Install Bash 5 and Homebrew, then use
`./ait`. Tools with a `brew`/`brew_cask` mapping or a portable method install
normally; Linux-only release assets without a mapping are skipped with a clear
warning. See [`docs/platforms.md`](docs/platforms.md).

**Why isn't X installed?** Check `docs/not-included.md`, then open an issue with the tool, why it's better than what's here, and its maintenance status.

---

## Contributing

PRs welcome — new tools, Linux/WSL fixes, and documentation. Please read
[`CONTRIBUTING.md`](CONTRIBUTING.md). Before submitting, run `make lint`,
`make test`, and `make integration` where Docker is available. The GitHub
workflow may also run checks outside the Linux/WSL target scope.

## License

MIT — see [LICENSE](LICENSE). Each installed tool keeps its own license.
