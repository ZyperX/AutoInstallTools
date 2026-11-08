# Adding a tool

Adding a tool is a catalog-only change: one YAML entry in
[`catalog/tools.yaml`](../catalog/tools.yaml). No installer code is needed
unless the tool needs a new install method.

## Inclusion criteria

A tool is included when it is:

- **Relevant** to web, API, mobile (Android/iOS) or source-code AppSec work.
- **Maintained** upstream (recent releases or commits) or an accepted standard
  such as Burp Suite or Ghidra.
- **Distinct** from what is already here. Superseded tools are either left out
  and documented in [`not-included.md`](not-included.md), or kept as
  `opt_in: true` with a `notes:` line explaining the replacement.
- **Installable without secrets or a `curl | bash` pipeline.** Interactive
  licence prompts and manual downloads are acceptable for `manual` entries.
- **Pinnable** when it ships release binaries: a `version` plus a per-platform
  SHA-256 (or an upstream checksum file).

Every `desc` must be plain English and 48 characters or fewer.

## The entry

```yaml
  - name: x8
    desc: Hidden HTTP parameter discovery
    category: discovery
    tags: [web, api]
    method: github_release
    repo: Sh1Yo/x8
    version: v4.3.0
    asset:
      linux_amd64: x86_64-linux-x8.gz
      linux_arm64: x86_64-linux-x8.gz
    sha256:
      linux_amd64: "<verified sha256>"
      linux_arm64: "<verified sha256>"
    check: x8 --version
```

Required keys are `name`, `desc`, `category`, `tags` and `method`. Add `bin`
when the command differs from the tool name, `gui: true` for GUI apps, and
`opt_in: true` for tools that profiles must not select automatically.
See [`schema.md`](schema.md) for every field and method-specific key.

### Platform mappings

- Use `apt` for Debian/Ubuntu system packages.
- Add `brew` (formula) or `brew_cask` (GUI app) for macOS. Add `brew_bin` when
  the installed command differs from `bin`, and `brew_deps` for formula
  prerequisites of a portable method.
- Add `kali_apt` when Kali ships a package that may be used instead of an
  upstream release. It is only selected when the Kali candidate is at least the
  pinned `version`.
- Use `platforms: [linux, wsl]` only for Linux-only entries; macOS entries need
  a Homebrew mapping or a portable method.

### Pin the release

```bash
./scripts/pin.sh x8            # fill version/asset/sha256 from upstream
./scripts/pin.sh --all         # refresh every pinned entry
```

Review the generated asset and checksum carefully: upstreams occasionally
rename assets. The weekly `bump.yml` workflow runs the same refresh and opens a
PR.

## Verify

```bash
make lint
make test
./scripts/gen-readme.sh --write   # if the catalog changed
./scripts/check-links.sh
```

`make test` validates the schema, unique names, description length, platform
mappings, per-architecture checksums and the resolver. The README catalog block
is generated, so `gen-readme.sh --check` fails CI when it is stale.

## Open a PR

Use the [tool-request template](../.github/ISSUE_TEMPLATE/tool-request.yml) if
you want to discuss a tool first. For a PR, include the upstream link, why the
tool belongs, the profiles it should join, and whether it needs `opt_in`. Keep
one tool per commit where practical.
