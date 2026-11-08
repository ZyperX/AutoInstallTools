# Contributing

Bug fixes, documentation improvements, and carefully selected tools are welcome.
Please open an issue before large changes so the scope can be discussed.

## Adding a tool

Most additions should change only `catalog/tools.yaml`. Use an upstream,
maintained release or package source, choose the narrowest useful profile tags,
and provide a short `desc` of at most 48 characters, a category, and a working
`check`. For release archives, pin the version and per-platform SHA-256 values;
record how hashes were obtained when upstream does not publish them. Avoid
install-time scripts piped directly into a shell, credential handling, and
tools with overlapping purpose unless there is a clear tradeoff.

See [`docs/adding-tools.md`](docs/adding-tools.md) for the entry fields, the
inclusion criteria, platform mappings and the pinning workflow.

Run `make lint` and `make test` before submitting. Regenerate the README
catalog tables with `make readme` if the catalog changed, and run `make links`
to check documentation references. Include the command output and note any
platform or upstream behavior that could not be checked. Keep changes focused
and use conventional commit subjects where practical.

## Code changes

- Keep installation paths user-owned unless an OS package requires elevation.
- Keep `--dry-run` free of persistent changes and external device actions.
- Quote shell expansions and route install actions through the shared helpers.
- Update the catalog schema docs and README when command behavior changes.
- Never commit tokens, test targets, scan results, or private certificates.
