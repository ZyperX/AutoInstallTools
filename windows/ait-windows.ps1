#requires -Version 5.1
<#
.SYNOPSIS
  Windows companion for AutoInstallTools: install native GUI tools via winget
  and optionally set the WSL networking mode.

.DESCRIPTION
  Run from PowerShell (no admin unless a chosen winget package asks for it).
  The checklist uses Out-GridView when available and a numbered prompt
  otherwise. Caido, Ghidra and rust_ASC are not in winget, so they are
  downloaded from their official release channels.

.PARAMETER WslNetwork
  Set networkingMode under [wsl2] in %UserProfile%\.wslconfig to Mirrored or Nat.
  The file is backed up first and all other lines/comments are preserved.

.PARAMETER SkipTools
  Only apply -WslNetwork; do not show the tool checklist.

.EXAMPLE
  .\ait-windows.ps1

.EXAMPLE
  .\ait-windows.ps1 -WslNetwork Mirrored -SkipTools
#>
[CmdletBinding()]
param(
    [ValidateSet('Mirrored', 'Nat')]
    [string]$WslNetwork,

    [switch]$SkipTools
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Tools = @(
    [pscustomobject]@{
        Name        = 'Burp Suite Community'
        Description = 'Intercepting proxy (free edition) via winget'
        Kind        = 'winget'
        Package     = 'PortSwigger.BurpSuite.Community'
    },
    [pscustomobject]@{
        Name        = 'Burp Suite Professional'
        Description = 'Intercepting proxy (licensed) via winget'
        Kind        = 'winget'
        Package     = 'PortSwigger.BurpSuite.Professional'
    },
    [pscustomobject]@{
        Name        = 'Caido Desktop'
        Description = 'Modern web proxy (downloads the official Windows installer)'
        Kind        = 'caido'
        Package     = ''
    },
    [pscustomobject]@{
        Name        = 'jadx'
        Description = 'DEX to Java decompiler via winget'
        Kind        = 'winget'
        Package     = 'Skylot.jadx'
    },
    [pscustomobject]@{
        Name        = 'Ghidra'
        Description = 'Reverse engineering suite (GitHub release, needs JDK 21)'
        Kind        = 'ghidra'
        Package     = ''
    },
    [pscustomobject]@{
        Name        = 'Temurin JDK 21'
        Description = 'Java runtime for jadx, Ghidra and ZAP via winget'
        Kind        = 'winget'
        Package     = 'EclipseAdoptium.Temurin.21.JDK'
    },
    [pscustomobject]@{
        Name        = 'scrcpy'
        Description = 'Mirror and control an Android device via winget'
        Kind        = 'winget'
        Package     = 'Genymobile.scrcpy'
    },
    [pscustomobject]@{
        Name        = 'Android platform-tools'
        Description = 'adb and fastboot via winget'
        Kind        = 'winget'
        Package     = 'Google.PlatformTools'
    },
    [pscustomobject]@{
        Name        = 'rust_ASC'
        Description = 'Fast APK decompiler (GitHub release for Windows)'
        Kind        = 'rustasc'
        Package     = ''
    }
)

function Assert-GitHubAssetDigest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Asset,
        [Parameter(Mandatory)]
        [string]$Path
    )

    $digest = [string]$Asset.digest
    if ($digest -notmatch '^sha256:([0-9a-fA-F]{64})$') {
        throw "GitHub did not provide a SHA-256 digest for $($Asset.name); refusing an unverified download."
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ine $Matches[1]) {
        throw "SHA-256 mismatch for $($Asset.name)."
    }
}

function Install-WingetPackage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$PackageId
    )

    if (-not (Get-Command -Name winget -ErrorAction SilentlyContinue)) {
        throw 'winget is not available; install App Installer from the Microsoft Store.'
    }
    if ($PSCmdlet.ShouldProcess($PackageId, 'install with winget')) {
        & winget install --id $PackageId --exact --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "winget exited with code $LASTEXITCODE for $PackageId"
        }
    }
}

function New-DesktopShortcut {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Target
    )

    if (-not $PSCmdlet.ShouldProcess($Name, 'create a desktop shortcut')) {
        return
    }
    $desktop = [Environment]::GetFolderPath('Desktop')
    $link = Join-Path $desktop "$Name.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($link)
    $shortcut.TargetPath = $Target
    $shortcut.WorkingDirectory = Split-Path -Parent $Target
    $shortcut.Save()
}

function Install-Ghidra {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $headers = @{ 'User-Agent' = 'ait-windows' }
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest' -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -match '^ghidra_.*_PUBLIC_.*\.zip$' } | Select-Object -First 1
    if (-not $asset) {
        throw 'No Ghidra zip asset found in the latest release.'
    }

    $destination = Join-Path $env:LOCALAPPDATA "Programs\Ghidra\$($release.tag_name)"
    if ($PSCmdlet.ShouldProcess($destination, 'download and expand Ghidra')) {
        $zip = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
        Assert-GitHubAssetDigest -Asset $asset -Path $zip
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Expand-Archive -Path $zip -DestinationPath $destination -Force
        Remove-Item -Path $zip -Force
        $runner = Get-ChildItem -Path $destination -Recurse -Filter 'ghidraRun.bat' | Select-Object -First 1
        if ($runner) {
            New-DesktopShortcut -Name 'Ghidra' -Target $runner.FullName
        }
    }
}

function Install-Caido {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $release = Invoke-RestMethod -Uri 'https://api.caido.io/releases/latest'
    $asset = $release.links | Where-Object { $_.kind -eq 'desktop' -and $_.os -eq 'windows' } | Select-Object -First 1
    if (-not $asset) {
        throw 'No Caido Windows desktop installer found.'
    }
    $installer = Join-Path $env:TEMP 'caido-desktop-installer.exe'
    if ($PSCmdlet.ShouldProcess($asset.link, 'download the Caido installer')) {
        Invoke-WebRequest -Uri $asset.link -OutFile $installer -UseBasicParsing
        Write-Output "Downloaded $installer. Finish the installer window that opens."
        Start-Process -FilePath $installer
    }
}

function Install-RustAsc {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $headers = @{ 'User-Agent' = 'ait-windows' }
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/MG1937/rust_ASC/releases/latest' -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -match '^rust_ASC-windows-x86_64\.exe$' } | Select-Object -First 1
    if (-not $asset) {
        throw 'No rust_ASC Windows x86_64 asset found.'
    }
    $directory = Join-Path $env:LOCALAPPDATA "Programs\rust_ASC\$($release.tag_name)"
    $destination = Join-Path $directory 'rust_ASC.exe'
    if ($PSCmdlet.ShouldProcess($destination, 'download rust_ASC')) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $download = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $download -UseBasicParsing
        Assert-GitHubAssetDigest -Asset $asset -Path $download
        Move-Item -LiteralPath $download -Destination $destination -Force
        New-DesktopShortcut -Name 'rust_ASC' -Target $destination
    }
}

function Select-Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Catalog
    )

    if (Get-Command -Name Out-GridView -ErrorAction SilentlyContinue) {
        $picked = $Catalog |
            Select-Object -Property Name, Description |
            Out-GridView -Title 'AutoInstallTools: pick Windows tools (Ctrl+click, then OK)' -OutputMode Multiple
        if (-not $picked) {
            return @()
        }
        return @($Catalog | Where-Object { $picked.Name -contains $_.Name })
    }

    Write-Output ''
    Write-Output 'Available Windows tools:'
    for ($i = 0; $i -lt $Catalog.Count; $i++) {
        Write-Output ('  {0,2}) {1} - {2}' -f ($i + 1), $Catalog[$i].Name, $Catalog[$i].Description)
    }
    $answer = Read-Host 'Select tools (1,3,5-9 | all | Enter=cancel)'
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return @()
    }

    $indexes = New-Object System.Collections.Generic.List[int]
    foreach ($part in ($answer -split ',')) {
        $piece = $part.Trim()
        if ($piece -eq 'all' -or $piece -eq 'a') {
            for ($i = 1; $i -le $Catalog.Count; $i++) { $indexes.Add($i) }
        }
        elseif ($piece -match '^(\d+)-(\d+)$') {
            $low = [int]$Matches[1]
            $high = [int]$Matches[2]
            for ($i = $low; $i -le $high; $i++) { $indexes.Add($i) }
        }
        elseif ($piece -match '^\d+$') {
            $indexes.Add([int]$piece)
        }
    }

    return @($indexes | Sort-Object -Unique | Where-Object { $_ -ge 1 -and $_ -le $Catalog.Count } | ForEach-Object { $Catalog[$_ - 1] })
}

function Set-WslNetworkingMode {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Mirrored', 'Nat')]
        [string]$Mode
    )

    $value = $Mode.ToLowerInvariant()
    if ($Mode -eq 'Mirrored' -and [Environment]::OSVersion.Version.Build -lt 22621) {
        throw "Windows build $([Environment]::OSVersion.Version.Build) is too old for mirrored networking; build 22621 or newer is required."
    }
    $config = Join-Path $env:USERPROFILE '.wslconfig'
    $raw = ''
    $lines = @()
    if (Test-Path -Path $config) {
        $raw = [System.IO.File]::ReadAllText($config)
        $lines = [System.IO.File]::ReadAllLines($config)
    }
    $newline = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }

    $output = New-Object System.Collections.Generic.List[string]
    $inWsl2 = $false
    $done = $false
    foreach ($line in $lines) {
        $clean = $line.TrimEnd("`r")
        if ($clean -match '^\s*\[wsl2\]\s*$') {
            $inWsl2 = $true
            $output.Add($clean)
            continue
        }
        if ($clean -match '^\s*\[') {
            if ($inWsl2 -and -not $done) {
                $output.Add("networkingMode=$value")
                $done = $true
            }
            $inWsl2 = $false
            $output.Add($clean)
            continue
        }
        if ($inWsl2 -and -not $done -and $clean -match '^\s*networkingMode\s*=') {
            $output.Add("networkingMode=$value")
            $done = $true
            continue
        }
        $output.Add($clean)
    }
    if (-not $done) {
        if (-not $inWsl2) { $output.Add('[wsl2]') }
        $output.Add("networkingMode=$value")
    }

    if (-not $PSCmdlet.ShouldProcess($config, "set networkingMode=$value")) {
        return
    }
    if (Test-Path -Path $config) {
        $stamp = Get-Date -Format 'yyyyMMddTHHmmssZ'
        Copy-Item -Path $config -Destination "$config.ait-backup-$stamp"
        Write-Output "Backed up $config to $config.ait-backup-$stamp"
    }
    [System.IO.File]::WriteAllText($config, (($output -join $newline) + $newline))
    Write-Output "Wrote networkingMode=$value to $config"
    Write-Output 'Apply it from PowerShell with: wsl.exe --shutdown (closes every WSL terminal).'
}

if ($WslNetwork) {
    Set-WslNetworkingMode -Mode $WslNetwork
}

if (-not $SkipTools) {
    $selected = @(Select-Tool -Catalog @($Tools))
    foreach ($tool in $selected) {
        Write-Output ''
        Write-Output "== $($tool.Name) =="
        try {
            switch ($tool.Kind) {
                'winget' { Install-WingetPackage -PackageId $tool.Package }
                'ghidra' { Install-Ghidra }
                'caido' { Install-Caido }
                'rustasc' { Install-RustAsc }
                default { Write-Output $tool.Description }
            }
        }
        catch {
            Write-Warning "$($tool.Name): $($_.Exception.Message)"
        }
    }
}

Write-Output ''
Write-Output 'Windows companion finished. Reopen your terminal so PATH changes apply.'
