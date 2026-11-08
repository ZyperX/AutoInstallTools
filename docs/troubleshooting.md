# Troubleshooting

Start with `ait doctor` and `ait list --installed`. Installation failures are
recorded under `~/.local/share/ait/state/failed-tools`; logs are under
`~/.local/share/ait/logs/` when a method produces a log.

## `ait` cannot find a command after installation

Open a new shell or run `exec "$SHELL"`. The installer adds `~/.local/bin`, Go,
and Cargo user bin directories to the selected shell startup file. Check `PATH`
and the managed manifest with `ait doctor`.

## Catalog parsing or download errors

The CLI bootstraps a pinned mikefarah `yq` binary and verifies its SHA-256.
Confirm that `curl` is installed and that GitHub release downloads are reachable.
If checksum verification fails, stop and report the tool name and pinned version;
do not bypass the check.

## Apt asks for a password or fails

System package installs use `sudo apt-get`. Review the package list printed by
the installer before accepting the prompt. Update apt metadata and retry the
failed tool with `ait install --profile PROFILE --with TOOL`.

## Android device is missing

Check `adb devices`, authorize the computer on the device, and ensure USB
debugging is enabled. WSL users may need USB forwarding or wireless adb; see
[`wsl-mobile.md`](wsl-mobile.md). `ait frida-server` requires a rooted/test device or an
appropriate `su` setup to start the server.

## GUI apps do not appear in WSL

WSL GUI integration requires WSLg. Run `ait doctor` and see [`wsl-mobile.md`](wsl-mobile.md)
for Windows and display troubleshooting.
