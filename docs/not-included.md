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
| apt `adb` / `apktool` (as the only source) | years out of date | upstream platform-tools / apktool |

## Not currently included

| Tool | Why held back |
|---|---|
| `caido-cli` | The upstream download endpoint and asset mapping are not yet represented as a verified catalog entry. |
| `massdns` | Requires a maintained source-build path; `puredns` can still use an independently installed resolver. |
