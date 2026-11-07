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
| `github_release` | yes | `repo: owner/name`, optional `dest:` |
| `pipx` | yes | `pypi: <name>` |
| `npm` | yes | `npm: <package>` |
| `cargo` | yes | `crate: <name>` |
| `git` | yes | `git: <url>`, `dest:` (clone only) |
| `wget_mirror` | yes | `url:`, `dest:` |
| `runtime` | yes | `runtime: go\|rust\|node\|awscli` |
| `git_venv` | Phase 2 | `git:`, `dest:`, `bin:` (clone + isolated venv + wrapper) |
| `docker` | Phase 2 | pull image + wrapper script |
| `official_archive` | Phase 2 | vendor zip/tar + sha256 (platform-tools, Ghidra, jadx) |
| `manual` | Phase 2 | print instructions, record as manual |

Pinning fields (`version`, `asset`, `sha256` / `checksum_file`) are added for
`github_release` and `official_archive` in Phase 2.
