# Platforms

AutoInstallTools targets Linux and WSL2 first. Debian 12 and Kali are supported
and exercised in CI; macOS is a Homebrew-based beta. Arch and Fedora are not
supported yet.

| Platform | Status | System packages | Notes |
|---|---|---|---|
| Ubuntu 22.04 / 24.04 | Primary | `apt` | Main development and CI target. |
| Debian 12 | Supported | `apt` | CI runs the web and mobile profiles. |
| Kali Linux | Supported | `apt` | Prefers Kali packages when they are at least the pinned version. |
| WSL2 | Supported | `apt` inside the distro | Adds WSLg, `.desktop` and networking helpers. |
| macOS | Beta | Homebrew | Bash 5 and Homebrew are required; some Linux-only tools are skipped. |
| Arch / Fedora | Not supported | — | No package mappings or validation. |

## Detection

`detect_platform` reports `wsl`, `linux`, `macos` or `unknown`. WSL is detected
from `/proc/version`. For tests and cross-platform dry runs, `AIT_PLATFORM` can
override the result:

```bash
AIT_PLATFORM=macos ./ait list --profile web
```

`distro_id`, `distro_like` and `distro_is <id>` read `/etc/os-release`; tests
point `AIT_OS_RELEASE` at fixtures.

## How tools are selected

1. An explicit `platforms:` list in the catalog always wins.
2. Otherwise every tool is available on Linux and WSL.
3. On macOS, a tool is selectable when it has a `brew`/`brew_cask` mapping, a
   pinned `darwin_*` asset, or uses a method that works unchanged
   (`uv`, `pipx`, `npm`, `go`, `cargo`, `git_venv`, `git`, `wget_mirror`,
   `docker`). Everything else is skipped with a warning, including when it is
   named explicitly with `--with`.

## System packages

Linux uses `apt`. Homebrew is never bootstrapped with a remote shell script:
on macOS, install Homebrew from <https://brew.sh> and `ait install` will use
it. `--apt` is rejected by `ait uninstall` on macOS because Homebrew packages
are removed through the manifest's `brew:`/`cask:` paths.

### Catalog platform fields

| Field | Example | Meaning |
|---|---|---|
| `brew` | `brew: [nmap]` | Formula installs the tool; authoritative on macOS. |
| `brew_cask` | `brew_cask: [zap]` | Cask for a GUI app. |
| `brew_bin` | `brew_bin: fd` | Binary name after a formula install when it differs from `bin`. |
| `brew_deps` | `brew_deps: [libpcap]` | Formula prerequisites for a portable method such as `go`. |
| `kali_apt` | `kali_apt: [feroxbuster]` | Kali package to prefer when its candidate is at least the pinned `version`. |

## Kali package preference

For non-`apt` methods, Kali's own package is used only when it is not stale:

1. The entry sets `kali_apt`.
2. `apt-cache policy <package>` reports a candidate.
3. `dpkg --compare-versions <candidate> ge <version>` succeeds.

Otherwise the normal pinned upstream install runs. This keeps Kali's patched
packages while never replacing a newer upstream release with an older one. The
same rule is covered by `tests/platform.bats`.

## macOS beta details

- Bash 5+ is required (`brew install bash`); macOS's `/bin/bash` is 3.2.
- Homebrew formula and cask names are declared per tool in the catalog.
- `./install.sh` is the legacy Linux bootstrap and is not supported on macOS;
  use `./ait`.
- CI does not run a macOS job. The beta is validated with tests and formula
  names from the Homebrew API, not on macOS hardware.
- Linux-only release assets without a Homebrew mapping are skipped rather than
  installed from an incompatible archive.
