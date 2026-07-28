#Requires -Version 5.1
<#
.SYNOPSIS
  Copies configured local folders into the OneDrive sync folder with robocopy.
  OneDrive then uploads those files to the cloud.

.PARAMETER ConfigPath
  Path to folders.json (default: next to this script).

.PARAMETER WhatIf
  Print the robocopy commands without running them.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "folders.json"),
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Get-OneDriveRoot {
    param([string]$Configured)

    if ($Configured) {
        if (-not (Test-Path -LiteralPath $Configured)) {
            throw "Configured oneDriveRoot does not exist: $Configured"
        }
        return (Resolve-Path -LiteralPath $Configured).Path
    }

    foreach ($candidate in @($env:OneDriveCommercial, $env:OneDrive, $env:OneDriveConsumer)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "Could not find a OneDrive folder. Set oneDriveRoot in folders.json or sign in to OneDrive."
}

function Write-Log {
    param([string]$Message, [string]$LogFile)
    $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -LiteralPath $LogFile -Value $line
    Write-Host $line
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$oneDriveRoot = Get-OneDriveRoot -Configured ([string]$config.oneDriveRoot)
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir ("backup-{0:yyyyMMdd}.log" -f (Get-Date))

$defaults = $config.defaults
$defaultMirror = [bool]$defaults.mirror
$defaultExcludeDirs = @($defaults.excludeDirs)
$defaultExcludeFiles = @($defaults.excludeFiles)

$folders = @($config.folders | Where-Object { $_.enabled -eq $true })
if ($folders.Count -eq 0) {
    Write-Log "No enabled folders in config. Edit folders.json and set enabled: true." $logFile
    exit 0
}

Write-Log "OneDrive root: $oneDriveRoot" $logFile
Write-Log ("Folders to back up: {0}" -f $folders.Count) $logFile

$failed = 0

foreach ($folder in $folders) {
    $name = [string]$folder.name
    $source = [string]$folder.source
    $destRel = [string]$folder.dest

    if (-not $name) { $name = Split-Path -Leaf $source }
    if (-not $source -or -not $destRel) {
        Write-Log "SKIP incomplete entry (need source + dest): $name" $logFile
        $failed++
        continue
    }

    if (-not (Test-Path -LiteralPath $source)) {
        Write-Log "SKIP missing source [$name]: $source" $logFile
        $failed++
        continue
    }

    if ([System.IO.Path]::IsPathRooted($destRel)) {
        $dest = $destRel
    } else {
        $dest = Join-Path $oneDriveRoot $destRel
    }

    $mirror = if ($null -ne $folder.mirror) { [bool]$folder.mirror } else { $defaultMirror }
    $excludeDirs = if ($folder.excludeDirs) { @($folder.excludeDirs) } else { $defaultExcludeDirs }
    $excludeFiles = if ($folder.excludeFiles) { @($folder.excludeFiles) } else { $defaultExcludeFiles }

    New-Item -ItemType Directory -Force -Path $dest | Out-Null

    # /E  subdirs including empty
    # /XO skip older destination files (incremental)
    # /FFT 2-second FAT time tolerance (helps with cloud sync)
    # /R:2 /W:5 limited retries so the job does not hang
    # /MT:8 multithreaded copy
    # /NFL /NDL quieter logs; /NP no progress percent
    $roboArgs = @(
        $source, $dest,
        "/E", "/XO", "/FFT",
        "/R:2", "/W:5", "/MT:8",
        "/NFL", "/NDL", "/NP",
        "/TEE", "/LOG+:$logFile"
    )

    if ($mirror) {
        # WARNING: deletes files on dest that are gone from source
        $roboArgs += "/MIR"
        # /MIR already implies /E; keep both is fine, /MIR wins for delete behavior
    }

    if ($excludeDirs.Count -gt 0) {
        $roboArgs += "/XD"
        $roboArgs += $excludeDirs
    }
    if ($excludeFiles.Count -gt 0) {
        $roboArgs += "/XF"
        $roboArgs += $excludeFiles
    }

    Write-Log "[$name] $source -> $dest  (mirror=$mirror)" $logFile

    if ($WhatIf) {
        Write-Log ("WhatIf: robocopy " + ($roboArgs -join " ")) $logFile
        continue
    }

    & robocopy @roboArgs
    $code = $LASTEXITCODE

    # robocopy: 0-7 = success/partial success; 8+ = failure
    if ($code -ge 8) {
        Write-Log "[$name] FAILED robocopy exit code $code" $logFile
        $failed++
    } else {
        Write-Log "[$name] OK robocopy exit code $code" $logFile
    }
}

Write-Log ("Done. Failures: {0}" -f $failed) $logFile

if ($failed -gt 0) { exit 1 }
exit 0
