# WSL2 setup

AutoInstallTools installs the same user-space tools inside WSL2 as on a native
Ubuntu host. This page covers the Windows-specific pieces: GUI apps, shared
networking, adb, and the Windows companion.

## Requirements

- Windows 11 (or Windows 10 22H2 with the Microsoft Store version of WSL).
- WSL2, not WSL1: `wsl.exe -l -v` shows `VERSION 2`.
- WSLg for GUI apps: `wsl.exe --version` lists `WSLg version`.

```bash
./ait install --profile mobile --yes   # or web / all
./ait doctor                           # WSL, WSLg, adb and wsl-net checks
```

## GUI tools and the Start menu

WSLg runs Linux GUI applications as normal Windows windows. After an install,
`ait` writes `.desktop` launchers for installed GUI tools (Caido desktop,
jadx-gui, Ghidra, ZAP) to `~/.local/share/applications`. WSL exposes that
directory in the Windows Start menu, so the apps appear there automatically.
scrcpy ships its own launcher from the Ubuntu package.

If fonts look blurry on a HiDPI display:

```bash
export GDK_SCALE=2                 # GTK apps
export _JAVA_OPTIONS='-Dsun.java2d.uiScale=2'   # Java apps: Burp, jadx-gui, Ghidra
```

Daily-driver GUI apps such as Burp Suite and Caido usually feel better natively
on Windows; use the companion script below.

## Shared networking (mirrored mode)

With `networkingMode=mirrored`, Windows and WSL share one IP and `localhost`:
a WSL agent can reach Burp/Ghidra MCP on Windows, and Windows apps can reach a
proxy running in WSL. It needs Windows 11 22H2 (build 22621) or newer.

```bash
ait wsl-net status      # configured mode, live mode, restart-pending state
ait wsl-net mirrored    # or: nat
ait wsl-net toggle
ait wsl-net mirrored --dry-run   # show the .wslconfig diff only
```

The command edits only `networkingMode` under `[wsl2]` in
`%UserProfile%\.wslconfig`, creates the section/key if missing, preserves every
other line/comment and CRLF endings, and writes a backup
(`.wslconfig.ait-backup-<timestamp>`) before each change. Apply with:

```powershell
wsl.exe --shutdown
```

That closes every WSL terminal; reopen afterwards. The command offers to run it
only after an explicit yes. Notes:

- The same port cannot be bound on both sides.
- Windows/Hyper-V firewall may still block inbound connections.
- `hostAddressLoopback=true` is optional; mirrored mode already shares localhost.

The main menu shows the same toggle as **WSL networking: Mirrored [ON|OFF]**.

## adb and USB devices

WSL2 cannot see USB devices by default. Pick one:

1. **usbipd-win (recommended):** `winget install usbipd`, then in an elevated
   PowerShell `usbipd bind --busid <id>` and `usbipd attach --wsl --busid <id>`.
2. **Wireless debugging:** enable it on the phone and run
   `adb connect <phone-ip>:5555` inside WSL.
3. **Reuse the Windows adb server:** with mirrored networking,
   `export ADB_SERVER_SOCKET=tcp:localhost:5037`.

Only one adb server may own port 5037: run adb in WSL **or** Windows, not both.
`ait doctor` prints the connected/unauthorized/offline state and these hints.

`ait frida-server` reads the host Frida version and device ABI, verifies the
matching server download against the GitHub API sha256, pushes it to
`/data/local/tmp` and confirms it with `frida-ps`.

## Proxy CA

```bash
ait proxy-ca --burp ~/Downloads/cacert.der
ait proxy-ca --caido ~/ca.crt
ait proxy-ca --mitmproxy
```

The certificate is normalised to PEM and written as `<subject_hash_old>.0`.
The command prints both the user-store steps and the system-store steps,
including the Android 14+ APEX `conscrypt` cacerts overlay and its
non-persistence across reboots (use a Magisk module such as
MagiskTrustUserCerts for that). Apps that pin certificates still need patching.

## Windows companion

Run in PowerShell:

```powershell
.\windows\ait-windows.ps1                        # checklist of native GUI tools
.\windows\ait-windows.ps1 -WslNetwork Mirrored   # also edit .wslconfig
.\windows\ait-windows.ps1 -WslNetwork Nat -SkipTools
```

The checklist uses `Out-GridView` when available and a numbered prompt
otherwise. winget packages: Burp Suite Community/Professional, jadx, Temurin
JDK 21, scrcpy, Android platform-tools. Caido, Ghidra and rust_ASC are not in
winget at the time of writing, so the script downloads their official release
artifacts (Caido installer, Ghidra zip, rust_ASC Windows binary) and creates
desktop shortcuts where it can. `-WslNetwork` follows the same backup/CRLF
rules as `ait wsl-net`.

## Troubleshooting

- **No Start-menu entries:** reopen the Start menu, or check
  `\\wsl$\<distro>\home\<user>\.local\share\applications` exists.
- **GUI app cannot connect to the display:** reopen the shell so `DISPLAY` and
  `WAYLAND_DISPLAY` are set; `ait doctor` reports this.
- **Mirrored mode did not apply:** run `wsl.exe --shutdown`, then
  `ait wsl-net status`; the Windows build must be 22621+.
- **adb sees no device:** re-attach with usbipd, or use wireless debugging; make
  sure only one adb server is running.
