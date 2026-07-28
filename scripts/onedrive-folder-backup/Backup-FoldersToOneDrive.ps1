#Requires -Version 5.1
<#
.SYNOPSIS
  Copies configured local folders into the OneDrive sync folder with robocopy.
  OneDrive then uploads those files to the cloud.

  Also writes a changelog of added / modified / removed files since the last
  successful backup (based on size + last-write time snapshots).

.PARAMETER ConfigPath
  Path to folders.json (default: next to this script).

.PARAMETER WhatIf
  Print robocopy commands and the changelog diff without copying or updating snapshots.
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

function Test-NameLikeAny {
    param(
        [string]$Name,
        [string[]]$Patterns
    )
    foreach ($pattern in $Patterns) {
        if ($Name -like $pattern) { return $true }
    }
    return $false
}

function Get-SourceManifest {
    param(
        [string]$SourceRoot,
        [string[]]$ExcludeDirs,
        [string[]]$ExcludeFiles
    )

    $manifest = @{}
    $excludeDirSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($d in $ExcludeDirs) {
        if ($d) { [void]$excludeDirSet.Add($d) }
    }

    $rootFull = (Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd('\')
    $pending = New-Object System.Collections.Queue
    $pending.Enqueue($rootFull)

    while ($pending.Count -gt 0) {
        $dir = $pending.Dequeue()

        try {
            $entries = Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop
        } catch {
            continue
        }

        foreach ($entry in $entries) {
            if ($entry.PSIsContainer) {
                if ($excludeDirSet.Contains($entry.Name)) { continue }
                $pending.Enqueue($entry.FullName)
                continue
            }

            if (Test-NameLikeAny -Name $entry.Name -Patterns $ExcludeFiles) { continue }

            $rel = $entry.FullName.Substring($rootFull.Length).TrimStart('\')
            $manifest[$rel] = @{
                Length       = [int64]$entry.Length
                LastWriteUtc = $entry.LastWriteTimeUtc.ToString("o")
            }
        }
    }

    return $manifest
}

function Get-ManifestDiff {
    param(
        [hashtable]$Previous,
        [hashtable]$Current
    )

    $added = New-Object System.Collections.Generic.List[string]
    $removed = New-Object System.Collections.Generic.List[string]
    $modified = New-Object System.Collections.Generic.List[object]

    if ($null -eq $Previous) {
        return [pscustomobject]@{
            IsInitial = $true
            Added     = @()
            Removed   = @()
            Modified  = @()
            FileCount = $Current.Count
        }
    }

    foreach ($key in $Current.Keys) {
        if (-not $Previous.ContainsKey($key)) {
            $added.Add($key)
            continue
        }
        $prev = $Previous[$key]
        $curr = $Current[$key]
        if ([int64]$prev.Length -ne [int64]$curr.Length -or [string]$prev.LastWriteUtc -ne [string]$curr.LastWriteUtc) {
            $modified.Add([pscustomobject]@{
                    Path     = $key
                    OldBytes = [int64]$prev.Length
                    NewBytes = [int64]$curr.Length
                })
        }
    }

    foreach ($key in $Previous.Keys) {
        if (-not $Current.ContainsKey($key)) {
            $removed.Add($key)
        }
    }

    return [pscustomobject]@{
        IsInitial = $false
        Added     = ($added | Sort-Object)
        Removed   = ($removed | Sort-Object)
        Modified  = ($modified | Sort-Object Path)
        FileCount = $Current.Count
    }
}

function ConvertTo-ManifestHashtable {
    param($SnapshotObject)

    $table = @{}
    if (-not $SnapshotObject -or -not $SnapshotObject.files) { return $table }

    foreach ($item in @($SnapshotObject.files)) {
        if (-not $item.path) { continue }
        $table[[string]$item.path] = @{
            Length       = [int64]$item.Length
            LastWriteUtc = [string]$item.LastWriteUtc
        }
    }
    return $table
}

function Save-ManifestSnapshot {
    param(
        [string]$Path,
        [string]$FolderName,
        [string]$Source,
        [hashtable]$Manifest
    )

    $files = foreach ($key in ($Manifest.Keys | Sort-Object)) {
        [pscustomobject]@{
            path         = $key
            Length       = $Manifest[$key].Length
            LastWriteUtc = $Manifest[$key].LastWriteUtc
        }
    }

    $payload = [ordered]@{
        folderName = $FolderName
        source     = $Source
        savedUtc   = (Get-Date).ToUniversalTime().ToString("o")
        fileCount  = $Manifest.Count
        files      = @($files)
    }

    $json = $payload | ConvertTo-Json -Depth 6 -Compress:$false
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function Add-ChangeLogSection {
    param(
        [System.Text.StringBuilder]$Builder,
        [string]$Title,
        [object[]]$Items,
        [scriptblock]$Formatter,
        [int]$Limit
    )

    if ($Items.Count -eq 0) { return }
    [void]$Builder.AppendLine("")
    [void]$Builder.AppendLine($Title)
    $take = [Math]::Min($Items.Count, $Limit)
    for ($i = 0; $i -lt $take; $i++) {
        [void]$Builder.AppendLine((& $Formatter $Items[$i]))
    }
    if ($Items.Count -gt $Limit) {
        [void]$Builder.AppendLine("  ... and $($Items.Count - $Limit) more")
    }
}

function Write-ChangeLogEntry {
    param(
        [string]$ChangeLogPath,
        [string]$FolderName,
        [string]$Source,
        $Diff,
        [int]$MaxFiles = 500
    )

    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## $stamp — $FolderName")
    [void]$sb.AppendLine("Source: $Source")

    if ($Diff.IsInitial) {
        [void]$sb.AppendLine("Initial snapshot: $($Diff.FileCount) file(s). No prior backup to compare.")
        Add-Content -LiteralPath $ChangeLogPath -Value $sb.ToString().TrimEnd() -Encoding UTF8
        return
    }

    $addedCount = @($Diff.Added).Count
    $modCount = @($Diff.Modified).Count
    $removedCount = @($Diff.Removed).Count

    [void]$sb.AppendLine("Summary: +$addedCount added, ~$modCount modified, -$removedCount removed ($($Diff.FileCount) files now)")

    if (($addedCount + $modCount + $removedCount) -eq 0) {
        [void]$sb.AppendLine("No file changes since last successful backup.")
        Add-Content -LiteralPath $ChangeLogPath -Value $sb.ToString().TrimEnd() -Encoding UTF8
        return
    }

    Add-ChangeLogSection -Builder $sb -Title "Added:" -Items @($Diff.Added) -Limit $MaxFiles -Formatter {
        param($p) "  + $p"
    }
    Add-ChangeLogSection -Builder $sb -Title "Modified:" -Items @($Diff.Modified) -Limit $MaxFiles -Formatter {
        param($m) "  ~ $($m.Path)  ($($m.OldBytes) -> $($m.NewBytes) bytes)"
    }
    Add-ChangeLogSection -Builder $sb -Title "Removed from source:" -Items @($Diff.Removed) -Limit $MaxFiles -Formatter {
        param($p) "  - $p"
    }

    Add-Content -LiteralPath $ChangeLogPath -Value $sb.ToString().TrimEnd() -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$oneDriveRoot = Get-OneDriveRoot -Configured ([string]$config.oneDriveRoot)
$logDir = Join-Path $PSScriptRoot "logs"
$stateDir = Join-Path $PSScriptRoot "state"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$logFile = Join-Path $logDir ("backup-{0:yyyyMMdd}.log" -f (Get-Date))
$changeLogFile = Join-Path $logDir "changelog.md"

$defaults = $config.defaults
$defaultMirror = [bool]$defaults.mirror
$defaultExcludeDirs = @($defaults.excludeDirs)
$defaultExcludeFiles = @($defaults.excludeFiles)
$changelogEnabled = if ($null -ne $defaults.changelog) { [bool]$defaults.changelog } else { $true }
$changelogMaxFiles = if ($defaults.changelogMaxFiles) { [int]$defaults.changelogMaxFiles } else { 500 }

$folders = @($config.folders | Where-Object { $_.enabled -eq $true })
if ($folders.Count -eq 0) {
    Write-Log "No enabled folders in config. Edit folders.json and set enabled: true." $logFile
    exit 0
}

Write-Log "OneDrive root: $oneDriveRoot" $logFile
Write-Log ("Folders to back up: {0}" -f $folders.Count) $logFile
if ($changelogEnabled) {
    Write-Log "Changelog: $changeLogFile" $logFile
}

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
    $folderChangelog = if ($null -ne $folder.changelog) { [bool]$folder.changelog } else { $changelogEnabled }

    New-Item -ItemType Directory -Force -Path $dest | Out-Null

    $safeName = ($name -replace '[<>:"/\\|?*]', '_').Trim()
    $snapshotPath = Join-Path $stateDir "$safeName.json"
    $currentManifest = $null
    $diff = $null

    if ($folderChangelog) {
        Write-Log "[$name] Scanning source for changelog..." $logFile
        $currentManifest = Get-SourceManifest -SourceRoot $source -ExcludeDirs $excludeDirs -ExcludeFiles $excludeFiles
        $previousManifest = $null
        if (Test-Path -LiteralPath $snapshotPath) {
            $previousManifest = ConvertTo-ManifestHashtable -SnapshotObject (
                Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
            )
        }
        $diff = Get-ManifestDiff -Previous $previousManifest -Current $currentManifest

        if ($diff.IsInitial) {
            Write-Log "[$name] Changelog: initial snapshot ($($diff.FileCount) files)" $logFile
        } else {
            Write-Log ("[$name] Changelog: +{0} ~{1} -{2}" -f @($diff.Added).Count, @($diff.Modified).Count, @($diff.Removed).Count) $logFile
        }

        Write-ChangeLogEntry `
            -ChangeLogPath $changeLogFile `
            -FolderName $name `
            -Source $source `
            -Diff $diff `
            -MaxFiles $changelogMaxFiles
    }

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
        if ($folderChangelog -and $null -ne $currentManifest) {
            Save-ManifestSnapshot -Path $snapshotPath -FolderName $name -Source $source -Manifest $currentManifest
        }
    }
}

Write-Log ("Done. Failures: {0}" -f $failed) $logFile

if ($failed -gt 0) { exit 1 }
exit 0
