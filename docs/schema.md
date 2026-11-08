# Catalog schema

Every tool lives in [`catalog/tools.yaml`](../catalog/tools.yaml) as one entry.
Adding a tool is a catalog-only change — no code edits.

## Fields

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Unique command/identifier. |
| `desc` | yes | **≤ 48 chars**; shown in `ait list` and the menu. |
| `category` | yes | One of the categories below; the menu groups tools by it. |
| `tags` | yes | List; profiles select tools whose tags intersect the profile's tags. |
| `method` | yes | How it is installed (see below). |
| `bin` | no | Command used for the installed/health check (default: `name`). |
| `gui` | no | `true` for GUI apps; on WSL the menu labels these and leaves them unticked. |
| `check` | no | Command `ait doctor` runs to confirm the tool works. |
| `opt_in` | no | `true` = never selected by a profile; only via `--with`. |
| `platforms` | no | List; default `[linux]`. |
| `notes` | no | Free text (e.g. "superseded by X", extra dependencies). |

## Categories

`core`, `runtime`, `recon`, `proxy`, `discovery`, `vuln`, `api`, `js-secrets`,
`sast-sca`, `android`, `ios`, `reversing`, `wordlists`, `cloud`, `container`, `ai`.

## Tags / profiles

Tags used by profiles: `core`, `runtime`, `recon`, `web`, `api`, `mobile`,
`code`, `cloud`, `wordlists`, `ai`. Profiles are defined in
[`catalog/profiles.yaml`](../catalog/profiles.yaml).

## Methods

| Method | Implemented | Keys |
|---|---|---|
| `apt` | yes | `apt: [packages]` |
| `go` | yes | `go: <module>`, optional `apt_deps: [packages]` |
| `github_release` | yes | `repo: owner/name`, pinned `version`, per-platform `asset` and `sha256` or `checksum_file`, optional `dest:` |
| `pipx` | yes | `pypi: <name>` |
| `npm` | yes | `npm: <package>` |
| `cargo` | yes | `crate: <name>` |
| `git` | yes | `git: <url>`, `dest:` (clone only) |
| `wget_mirror` | yes | `url:`, `dest:` |
| `runtime` | yes | `runtime: go\|rust\|node\|awscli` |
| `git_venv` | yes | `git:`, `dest:`, `bin:` (clone + isolated venv + wrapper) |
| `docker` | yes | pull image + wrapper script |
| `official_archive` | yes | vendor zip/tar + pinned `version` and SHA-256/checksum file |
| `manual` | yes | print instructions, record as manual |

## Pinning

- `github_release` and `official_archive` may set `version` plus a per-platform
  `asset` map and `sha256` map (or `checksum_file`). A pinned binary entry must
  have a checksum; CI enforces it.
- `uv` and `pipx` may set `version` to pin an exact PyPI release (for example
  the compatible `frida-tools` / `objection` pair). Package pins are verified by
  uv/pip through the package index, not with a local sha256.
- Entries without `version` install the latest release and warn that they are
  unpinned.
