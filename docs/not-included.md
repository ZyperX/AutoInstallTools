# Not included (and why)

AutoInstallTools is curated: abandoned or fully superseded tools are left out,
or kept only as `opt_in` so a profile never installs them by default. Open an
issue if you disagree with a call here.

## Superseded — kept as `opt_in` only

| Tool | Use instead |
|---|---|
| `hakrawler` | `katana` |
| `assetfinder` | `subfinder` |
| `waybackurls` | `gau` / `waymore` |
| `dirsearch` | `ffuf` / `feroxbuster` |
| `gobuster` | `ffuf` / `feroxbuster` |

Install any of these explicitly with, e.g., `ait install --profile web --with hakrawler`.

## Dropped entirely

| Tool | Reason | Use instead |
|---|---|---|
| `exa` | archived | `eza` |
| `tplmap` | unmaintained | `SSTImap` |
| `LinkFinder` | unmaintained | `jsluice` / `xnLinkFinder` |
| `Sublist3r` | unmaintained | `subfinder` |
| `dirb` / `dirbuster` | superseded | `ffuf` / `feroxbuster` |
| apt `adb` / `apktool` (as the only source) | years out of date | upstream platform-tools / apktool (Phase 4) |

## Pending verification (not yet added)

| Tool | Why held back |
|---|---|
| `caido-cli` | Caido publishes no GitHub release assets; its caido.io download URL needs to be verified before adding an `official_archive` entry. |
| `massdns` | No apt package and no release binary; needs a from-source build. `puredns` is in the catalog but depends on `massdns` being on `PATH`. |
