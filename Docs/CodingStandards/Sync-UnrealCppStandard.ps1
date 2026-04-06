[CmdletBinding()]
param(
  [string]$SnapshotDate = (Get-Date -Format "yyyy-MM-dd"),
  [string]$Scope = "epic-cpp-standard",
  [string]$SourceUrl = "https://dev.epicgames.com/documentation/en-us/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine"
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$snapshotsRoot = Join-Path $scriptRoot "Snapshots"
$snapshotFolderName = "$SnapshotDate-$Scope"
$snapshotFolder = Join-Path $snapshotsRoot $snapshotFolderName
$pagePath = Join-Path $snapshotFolder "page.html"
$sourceTemplatePath = Join-Path $scriptRoot "Templates/SOURCE.template.md"
$sourceOutPath = Join-Path $snapshotFolder "SOURCE.md"

New-Item -ItemType Directory -Path $snapshotsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $snapshotFolder -Force | Out-Null

Write-Host "[CodingStandards] Downloading: $SourceUrl"
Invoke-WebRequest -Uri $SourceUrl -OutFile $pagePath

if (-not (Test-Path $sourceOutPath) -and (Test-Path $sourceTemplatePath)) {
  Copy-Item -Path $sourceTemplatePath -Destination $sourceOutPath
}

Write-Host "[CodingStandards] Snapshot created:"
Write-Host "  $snapshotFolder"
Write-Host "[CodingStandards] Next:"
Write-Host "  1) Fill SOURCE.md"
Write-Host "  2) Commit snapshot in docs-only scope"
