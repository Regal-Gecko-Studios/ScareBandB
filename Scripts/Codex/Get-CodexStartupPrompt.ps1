[CmdletBinding()]
param(
  [string]$Task,
  [switch]$IncludePrivate,
  [switch]$CopyToClipboard,
  [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
  param([string]$ExplicitRepoRoot)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitRepoRoot)) {
    $candidate = [System.IO.Path]::GetFullPath($ExplicitRepoRoot)
    if (-not (Test-Path -LiteralPath $candidate)) {
      throw "RepoRoot does not exist: $candidate"
    }

    return $candidate
  }

  $repoRoot = ((git rev-parse --show-toplevel 2>$null) | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    throw "Get-CodexStartupPrompt.ps1 must be run from inside a git repository or passed -RepoRoot."
  }

  return $repoRoot.Trim()
}

function Test-IsExcludedMarkdownPath {
  param([Parameter(Mandatory)][string]$RelativePath)

  $excludedPrefixes = @(
    ".git/",
    ".codex-local/",
    "Binaries/",
    "DerivedDataCache/",
    "Intermediate/",
    "Saved/",
    "website/.docusaurus/",
    "website/build/",
    "website/node_modules/"
  )

  foreach ($prefix in $excludedPrefixes) {
    if ($RelativePath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

function Get-RepoMarkdownPaths {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  $markdownFiles = Get-ChildItem -LiteralPath $ResolvedRepoRoot -Recurse -File -Filter "*.md"
  $relativePaths = New-Object System.Collections.Generic.List[string]

  foreach ($file in $markdownFiles) {
    $relativePath = [System.IO.Path]::GetRelativePath($ResolvedRepoRoot, $file.FullName).Replace("\", "/")
    if ($relativePath -eq "AGENTS.md") {
      continue
    }
    if (Test-IsExcludedMarkdownPath -RelativePath $relativePath) {
      continue
    }

    $relativePaths.Add($relativePath) | Out-Null
  }

  $docsPaths = @($relativePaths | Where-Object { $_ -like "Docs/*" } | Sort-Object -Unique)
  $otherPaths = @($relativePaths | Where-Object { $_ -notlike "Docs/*" } | Sort-Object -Unique)

  return @($docsPaths + $otherPaths)
}

function Get-CodingStandardsSnapshotInfo {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  $snapshotsRoot = Join-Path $ResolvedRepoRoot "Docs\CodingStandards\Snapshots"
  if (-not (Test-Path -LiteralPath $snapshotsRoot)) {
    return [pscustomobject]@{
      Exists = $false
      Name = $null
      SnapshotDate = $null
      IsStale = $false
    }
  }

  $candidates = New-Object System.Collections.Generic.List[object]
  foreach ($dir in @(Get-ChildItem -LiteralPath $snapshotsRoot -Directory)) {
    if ($dir.Name -match '^(?<date>\d{4}-\d{2}-\d{2})-epic-cpp-standard$') {
      $snapshotDate = [datetime]::ParseExact($Matches.date, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
      $candidates.Add([pscustomobject]@{
          Name = $dir.Name
          SnapshotDate = $snapshotDate
        }) | Out-Null
    }
  }

  $latest = @($candidates | Sort-Object SnapshotDate -Descending | Select-Object -First 1)
  if ($latest.Count -eq 0) {
    return [pscustomobject]@{
      Exists = $false
      Name = $null
      SnapshotDate = $null
      IsStale = $false
    }
  }

  $snapshotDate = $latest[0].SnapshotDate
  $isStale = $snapshotDate.Date.AddMonths(6) -lt (Get-Date).Date

  return [pscustomobject]@{
    Exists = $true
    Name = $latest[0].Name
    SnapshotDate = $snapshotDate
    IsStale = $isStale
  }
}

$resolvedRepoRoot = Resolve-RepoRoot -ExplicitRepoRoot $RepoRoot
$repoMarkdownPaths = @(Get-RepoMarkdownPaths -ResolvedRepoRoot $resolvedRepoRoot)
$snapshotInfo = Get-CodingStandardsSnapshotInfo -ResolvedRepoRoot $resolvedRepoRoot
$privateContextPath = ".codex-local/Private-Context.md"
$privateContextExists = Test-Path -LiteralPath (Join-Path $resolvedRepoRoot $privateContextPath)

if ($IncludePrivate -and -not $privateContextExists) {
  Write-Warning "Private context requested but not found: $privateContextPath"
}

if ($CopyToClipboard -and -not (Get-Command Set-Clipboard -ErrorAction SilentlyContinue)) {
  throw "Set-Clipboard is not available in this PowerShell session."
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Read AGENTS.md first.") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Then read these repo markdown docs before doing substantial work:") | Out-Null

foreach ($relativePath in $repoMarkdownPaths) {
  $lines.Add("- $relativePath") | Out-Null
}

$lines.Add("") | Out-Null

if ($snapshotInfo.Exists) {
  $lines.Add(("Current latest Unreal C++ standard snapshot: Docs/CodingStandards/Snapshots/{0} ({1:yyyy-MM-dd})." -f $snapshotInfo.Name, $snapshotInfo.SnapshotDate)) | Out-Null
  if ($snapshotInfo.IsStale) {
    $lines.Add("It is older than six months. Refresh it with `pwsh -File Docs/CodingStandards/Sync-UnrealCppStandard.ps1` before treating the local standard reference as current.") | Out-Null
  }
  else {
    $lines.Add("It is not older than six months.") | Out-Null
  }
}
else {
  $lines.Add("No local Unreal C++ standard snapshot was found under Docs/CodingStandards/Snapshots/.") | Out-Null
}

$lines.Add("If this task touches C++ or style-sensitive code, scrutinize Docs/CodingStandards/README.md and the latest snapshot folder first.") | Out-Null

if (-not [string]::IsNullOrWhiteSpace($Task)) {
  $lines.Add("") | Out-Null
  $lines.Add("Task:") | Out-Null
  $lines.Add("- $Task") | Out-Null
}

if ($IncludePrivate -and $privateContextExists) {
  $lines.Add("") | Out-Null
  $lines.Add("Also use .codex-local/Private-Context.md for my local preferences.") | Out-Null
}

$prompt = $lines -join "`r`n"

if ($CopyToClipboard) {
  Set-Clipboard -Value $prompt
  Write-Host "[Codex Prompt] Copied startup prompt to clipboard." -ForegroundColor Green
}

Write-Output $prompt
