#Requires -Version 5.1
<#
.SYNOPSIS
  Registers a Windows Scheduled Task that runs Backup-FoldersToOneDrive.ps1 on a schedule.

.PARAMETER IntervalMinutes
  How often to run (default: 60).

.PARAMETER TaskName
  Scheduled Task name (default: OneDrive Folder Backup).

.PARAMETER AtLogOn
  Also run once at user logon (default: on).

.PARAMETER Uninstall
  Remove the scheduled task instead of installing it.
#>
[CmdletBinding()]
param(
    [int]$IntervalMinutes = 60,
    [string]$TaskName = "OneDrive Folder Backup",
    [switch]$AtLogOn = $true,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed scheduled task: $TaskName"
    exit 0
}

if ($IntervalMinutes -lt 5) {
    throw "IntervalMinutes must be at least 5 so OneDrive has time to sync between runs."
}

$scriptPath = Join-Path $PSScriptRoot "Backup-FoldersToOneDrive.ps1"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Backup script not found: $scriptPath"
}

# Run when the user is logged on so OneDrive can upload the copied files.
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$triggers = @(
    (New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(2)) `
        -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
        -RepetitionDuration (New-TimeSpan -Days 9999))
)

if ($AtLogOn) {
    $triggers += New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 6)

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $triggers `
    -Settings $settings `
    -Principal $principal `
    -Force | Out-Null

Write-Host "Scheduled task installed: $TaskName"
Write-Host "  Script : $scriptPath"
Write-Host "  Every  : $IntervalMinutes minute(s)"
Write-Host "  AtLogOn: $AtLogOn"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit folders.json (enable folders, set source/dest paths)"
Write-Host "  2. Test:  powershell -File `"$scriptPath`""
Write-Host "  3. Or run the task now from Task Scheduler"
