[CmdletBinding()]
param(
  # Hook parameters (optional for manual use)
  [string]$OldRev,
  [string]$NewRev,
  [int]$Flag = 1,

  # Manual / control flags
  [switch]$Force,           # Always run regen+build even if no structural triggers detected
  [switch]$CleanSaved,      # Delete the Saved directory
  [switch]$CleanCache,      # Delete the DerivedDataCache directory
  [switch]$NoRegen,         # Skip generating project files
  [switch]$NoBuild,         # Skip building
  [switch]$NonInteractive,  # Tells the script to avoid prompting the user
  [switch]$DryRun,          # Validate detection/prompt flow without cleanup/build

  # Optional: explicitly point at a .code-workspace file
  [string]$WorkspacePath,

  [ValidateSet("Development", "Debug")]
  [string]$Config = "Development",

  [ValidateSet("Win64")]
  [string]$Platform = "Win64"
)

$ErrorActionPreference = "Stop"

$projectContextHelper = Join-Path $PSScriptRoot "ProjectContext.ps1"
if (-not (Test-Path -LiteralPath $projectContextHelper)) {
  throw "Project context helper not found: $projectContextHelper"
}
. $projectContextHelper

function Info($msg) { Write-Host "[UE Sync] $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "[UE Sync] $msg" -ForegroundColor Yellow }
function Err ($msg) { Write-Host "[UE Sync] $msg" -ForegroundColor Red }
function Success($msg) { Write-Host "[UE Sync] $msg" -ForegroundColor Green }

function Test-IsInteractiveConsole {
  try {
    if (-not [Environment]::UserInteractive) { return $false }
    if ($env:CI -or $env:GITHUB_ACTIONS -or $env:TF_BUILD -or $env:JENKINS_URL) { return $false }
    if ($Host.Name -eq "ServerRemoteHost") { return $false }

    # Preferred signal: real console host with usable RawUI and non-redirected input.
    if ($Host.UI -and $Host.UI.RawUI -and -not [Console]::IsInputRedirected) {
      return $true
    }

    # Fallback for hook contexts launched from an interactive shell (TTY can be hidden).
    if ($env:TERM -and $env:TERM -ne "dumb") { return $true }

    return $false
  }
  catch { return $false }
}

function Test-CanPrompt {
  try {
    if (-not [Environment]::UserInteractive) { return $false }
    if (-not $Host.UI -or -not $Host.UI.RawUI) { return $false }
    if ([Console]::IsInputRedirected) { return $false }
    if ([Console]::IsOutputRedirected) { return $false }
    return $true
  }
  catch { return $false }
}

function Test-EnvTrue {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
  switch ($Value.Trim().ToLowerInvariant()) {
    "1" { return $true }
    "true" { return $true }
    "yes" { return $true }
    default { return $false }
  }
}


function Remove-IfExists {
  param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$NonInteractive,
    [int]$MaxAutoRetries = 2
  )

  if (-not (Test-Path $Path)) { return $true }

  $attempt = 0
  while ($true) {
    try {
      # Some hosts leave stale progress rows after large recursive deletes.
      # Suppress progress for cleanup to keep hook/manual output stable.
      $oldProgressPreference = $ProgressPreference
      try {
        $ProgressPreference = "SilentlyContinue"
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      }
      finally {
        $ProgressPreference = $oldProgressPreference
      }
      return $true
    }
    catch {
      $attempt++
      $errMsg = $_.Exception.Message

      if ($attempt -le $MaxAutoRetries) {
        Start-Sleep -Milliseconds 250
        continue
      }

      if ($NonInteractive) {
        Warn "Could not clean '$Path' because a file is in use. Continuing without deleting this folder."
        Warn $errMsg
        return $false
      }

      Warn "Could not clean '$Path' because a file is in use."
      Warn "Close apps/files using this path (for example VS Code tab, indexer, compiler), then choose Retry."
      $choice = (Read-Host "[UE Sync] Cleanup failed. [R]etry / [S]kip cleanup / [A]bort").Trim().ToLowerInvariant()

      switch ($choice) {
        { $_ -in @("", "r", "retry") } {
          $attempt = 0
          continue
        }
        { $_ -in @("s", "skip") } {
          Warn "Skipping cleanup for '$Path'."
          return $false
        }
        default {
          throw "Aborted by user during cleanup of '$Path'."
        }
      }
    }
  }
}

function Get-UProjectPath {
  $projectContext = Get-ProjectContext -RepoRoot (Get-Location).Path -WorkspacePath $WorkspacePath
  return $projectContext.UProjectPath
}

function Get-ProjectName([string]$uprojectPath) {
  $projectContext = Get-ProjectContext -RepoRoot (Get-Location).Path -UProjectPath $uprojectPath -WorkspacePath $WorkspacePath
  return $projectContext.ProjectName
}

function Add-DiagnosticAttempt([System.Collections.Generic.List[string]]$Attempts, [string]$Message) {
  if ($null -ne $Attempts) {
    [void]$Attempts.Add($Message)
  }
}

function Test-EngineRoot([string]$root) {
  if (-not $root) { return $false }
  if (-not (Test-Path $root)) { return $false }
  Test-Path (Join-Path $root "Engine\Build\BatchFiles\Build.bat")
}

function Resolve-PathRelativeTo([string]$baseDir, [string]$path) {
  if (-not $path) { return $null }
  if ([IO.Path]::IsPathRooted($path)) { return $path }
  Join-Path $baseDir $path
}

function Get-EngineRootFromWorkspace(
  [string]$repoRoot,
  [string]$explicitWorkspacePath,
  [System.Collections.Generic.List[string]]$attempts = $null
) {
  $wsFile = $null

  if ($explicitWorkspacePath) {
    $workspaceCandidate = Resolve-PathRelativeTo $repoRoot $explicitWorkspacePath
    Add-DiagnosticAttempt $attempts "workspace override path: '$workspaceCandidate'"
    $wsFile = Get-Item -LiteralPath $workspaceCandidate -ErrorAction SilentlyContinue
    if (-not $wsFile) {
      Add-DiagnosticAttempt $attempts "workspace override not found"
    }
  }
  else {
    $workspaceCandidates = @(Get-ChildItem -Path $repoRoot -Filter *.code-workspace -File -ErrorAction SilentlyContinue)
    if ($workspaceCandidates.Count -gt 0) {
      $wsFile = $workspaceCandidates | Select-Object -First 1
      Add-DiagnosticAttempt $attempts "workspace auto-discovery: using '$($wsFile.FullName)'"
    }
    else {
      Add-DiagnosticAttempt $attempts "workspace auto-discovery: no *.code-workspace in repo root"
    }
  }

  if (-not $wsFile) { return $null }

  try {
    $json = Get-Content $wsFile.FullName -Raw | ConvertFrom-Json
  }
  catch {
    Add-DiagnosticAttempt $attempts "workspace parse failed: $($wsFile.FullName) ($($_.Exception.Message))"
    return $null
  }

  $folders = @($json.folders)
  if (-not $folders -or $folders.Count -eq 0) {
    Add-DiagnosticAttempt $attempts "workspace has no folders[] entries"
    return $null
  }

  # Prefer folders named UE5 / UE*
  $preferred = $folders | Where-Object { $_.name -and $_.name -match '^UE' } | Select-Object -First 1
  if ($preferred) {
    $p = Resolve-PathRelativeTo $repoRoot $preferred.path
    Add-DiagnosticAttempt $attempts "workspace preferred UE folder '$($preferred.name)' -> '$p'"
    if (Test-EngineRoot $p) {
      Add-DiagnosticAttempt $attempts "workspace preferred UE folder validated"
      return $p
    }
  }

  # Otherwise, find any folder path that looks like UE_5.x and validates
  foreach ($f in $folders) {
    $p = Resolve-PathRelativeTo $repoRoot $f.path
    if (-not $p) { continue }
    $folderName = if ($f.name) { $f.name } else { "<unnamed>" }
    Add-DiagnosticAttempt $attempts "workspace folder '$folderName' -> '$p'"

    if ($p -match 'UE_\d' -and (Test-EngineRoot $p)) {
      Add-DiagnosticAttempt $attempts "workspace UE_* path validated"
      return $p
    }

    # If path points inside ...\Engine\..., walk up to root
    $idx = $p.ToLower().IndexOf("\engine\")
    if ($idx -ge 0) {
      $root = $p.Substring(0, $idx)
      Add-DiagnosticAttempt $attempts "workspace folder points into Engine subpath; testing root '$root'"
      if (Test-EngineRoot $root) {
        Add-DiagnosticAttempt $attempts "workspace Engine-subpath root validated"
        return $root
      }
    }

    # Path points to ...\Engine
    if ($p.ToLower().EndsWith("\engine")) {
      $root = Split-Path $p -Parent
      Add-DiagnosticAttempt $attempts "workspace folder points to Engine dir; testing root '$root'"
      if (Test-EngineRoot $root) {
        Add-DiagnosticAttempt $attempts "workspace Engine parent root validated"
        return $root
      }
    }
  }

  return $null
}

function Get-UProjectEngineAssociation(
  [string]$uprojectPath,
  [System.Collections.Generic.List[string]]$attempts = $null
) {
  if (-not $uprojectPath) {
    Add-DiagnosticAttempt $attempts ".uproject path not provided for EngineAssociation lookup"
    return $null
  }
  if (-not (Test-Path -LiteralPath $uprojectPath)) {
    Add-DiagnosticAttempt $attempts ".uproject not found for EngineAssociation lookup: $uprojectPath"
    return $null
  }

  try {
    $uprojectJson = Get-Content -LiteralPath $uprojectPath -Raw | ConvertFrom-Json
  }
  catch {
    Add-DiagnosticAttempt $attempts ".uproject parse failed for EngineAssociation lookup ($($_.Exception.Message))"
    return $null
  }

  $association = [string]$uprojectJson.EngineAssociation
  if ([string]::IsNullOrWhiteSpace($association)) {
    Add-DiagnosticAttempt $attempts ".uproject has no EngineAssociation value"
    return $null
  }

  Add-DiagnosticAttempt $attempts ".uproject EngineAssociation='$association'"
  return $association.Trim()
}

function Get-RegistryPropertyString([string]$keyPath, [string]$propertyName) {
  if (-not (Test-Path $keyPath)) { return $null }
  $props = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
  if (-not $props) { return $null }
  $property = $props.PSObject.Properties[$propertyName]
  if ($property) { return [string]$property.Value }
  return $null
}

function Get-EngineRootFromEngineAssociation(
  [string]$engineAssociation,
  [System.Collections.Generic.List[string]]$attempts = $null
) {
  if ([string]::IsNullOrWhiteSpace($engineAssociation)) { return $null }

  $hkcuBuilds = "Registry::HKEY_CURRENT_USER\SOFTWARE\Epic Games\Unreal Engine\Builds"
  if (Test-Path $hkcuBuilds) {
    $hkcuRoot = Get-RegistryPropertyString $hkcuBuilds $engineAssociation
    if ($hkcuRoot) {
      Add-DiagnosticAttempt $attempts "HKCU Builds[$engineAssociation] -> '$hkcuRoot'"
      if (Test-EngineRoot $hkcuRoot) {
        Add-DiagnosticAttempt $attempts "HKCU Builds[$engineAssociation] validated"
        return $hkcuRoot
      }
      Add-DiagnosticAttempt $attempts "HKCU Builds[$engineAssociation] failed engine-root validation"
    }
    else {
      Add-DiagnosticAttempt $attempts "HKCU Builds[$engineAssociation] not present"
    }
  }
  else {
    Add-DiagnosticAttempt $attempts "HKCU Builds registry key missing"
  }

  $hklmCandidates = @(
    "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine\$engineAssociation",
    "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\EpicGames\Unreal Engine\$engineAssociation"
  )
  foreach ($candidate in $hklmCandidates) {
    if (-not (Test-Path $candidate)) {
      Add-DiagnosticAttempt $attempts "HKLM candidate missing: $candidate"
      continue
    }

    $installedDirectory = Get-RegistryPropertyString $candidate "InstalledDirectory"
    if (-not $installedDirectory) {
      Add-DiagnosticAttempt $attempts "HKLM candidate has no InstalledDirectory: $candidate"
      continue
    }

    Add-DiagnosticAttempt $attempts "HKLM InstalledDirectory -> '$installedDirectory'"
    if (Test-EngineRoot $installedDirectory) {
      Add-DiagnosticAttempt $attempts "HKLM InstalledDirectory validated"
      return $installedDirectory
    }

    Add-DiagnosticAttempt $attempts "HKLM InstalledDirectory failed engine-root validation"
  }

  return $null
}

function Resolve-EngineRootForBuild([string]$workspacePathOverride, [string]$uprojectPath) {
  $projectContext = Get-ProjectContext `
    -RepoRoot (Get-Location).Path `
    -UProjectPath $uprojectPath `
    -WorkspacePath $workspacePathOverride

  $attempts = [System.Collections.Generic.List[string]]::new()
  $workspaceRoot = Get-EngineRootFromWorkspaceContext `
    -ProjectContext $projectContext `
    -WorkspacePath $workspacePathOverride `
    -Attempts $attempts
  if (-not [string]::IsNullOrWhiteSpace($workspaceRoot)) {
    Info "Engine root resolved from workspace: $workspaceRoot"
    return $workspaceRoot
  }

  foreach ($envVar in @("UE_ENGINE_DIR", "UE_ENGINE_ROOT", "UNREAL_ENGINE_DIR")) {
    $candidate = [string](Get-Item -Path "Env:$envVar" -ErrorAction SilentlyContinue).Value
    if ([string]::IsNullOrWhiteSpace($candidate)) {
      Add-DiagnosticAttempt $attempts "$envVar is unset"
      continue
    }

    Add-DiagnosticAttempt $attempts "$envVar -> '$candidate'"
    if (Test-EngineRoot $candidate) {
      Info "Engine root resolved from ${envVar}: $candidate"
      return $candidate
    }

    Add-DiagnosticAttempt $attempts "$envVar failed engine-root validation"
  }

  if (-not [string]::IsNullOrWhiteSpace($projectContext.EngineAssociation)) {
    Add-DiagnosticAttempt $attempts ".uproject EngineAssociation='$($projectContext.EngineAssociation)'"
  }
  else {
    Add-DiagnosticAttempt $attempts ".uproject has no EngineAssociation value"
  }

  $registryRoot = Get-EngineRootFromRegistryAssociation `
    -EngineAssociation $projectContext.EngineAssociation `
    -Attempts $attempts
  if (-not [string]::IsNullOrWhiteSpace($registryRoot)) {
    Info "Engine root resolved from registry using EngineAssociation '$($projectContext.EngineAssociation)': $registryRoot"
    return $registryRoot
  }

  $commonInstallRoot = Get-EngineRootFromCommonInstalls `
    -EngineAssociation $projectContext.EngineAssociation `
    -Attempts $attempts
  if (-not [string]::IsNullOrWhiteSpace($commonInstallRoot)) {
    Info "Engine root resolved from common install roots: $commonInstallRoot"
    return $commonInstallRoot
  }

  $attemptLines = if ($attempts.Count -gt 0) {
    $attempts | ForEach-Object { "- $_" }
  }
  else {
    @("- no discovery attempts were recorded")
  }
  $attemptText = $attemptLines -join "`n"

  throw @"
Could not resolve Unreal Engine install path for BUILD/RunUBT fallback.

Attempted sources (in order):
$attemptText

Action:
- Re-generate the VS Code workspace in Unreal so it contains the UE install folder under folders[].
- Or set UE_ENGINE_DIR / UE_ENGINE_ROOT / UNREAL_ENGINE_DIR on this machine.
- Or ensure the .uproject EngineAssociation maps to an installed engine in registry.
"@
}

function Get-UProjectProgId {
  # Example: ".uproject=Unreal.ProjectFile" -> returns "Unreal.ProjectFile"
  $assoc = cmd /c assoc .uproject 2>$null
  if (-not $assoc) { return $null }
  ($assoc -replace '^.*=').Trim()
}

$script:LastUVSResolution = $null

function Resolve-UVSPathFromRegistry {
  # Optional explicit override for local troubleshooting or deterministic tests.
  $explicitUvs = [string]$env:UE_SYNC_UVS_PATH
  if (-not [string]::IsNullOrWhiteSpace($explicitUvs)) {
    $resolvedExplicit = Resolve-PathRelativeTo (Get-Location).Path $explicitUvs
    if (Test-Path $resolvedExplicit) {
      return [pscustomobject]@{
        Path    = $resolvedExplicit
        Source  = "UE_SYNC_UVS_PATH"
        Command = "<env override>"
      }
    }
  }

  # Reads the same command Explorer runs for right-click "Generate Visual Studio project files"
  # and extracts UnrealVersionSelector.exe path from it.
  $progId = Get-UProjectProgId
  $candidateShellRoots = @()

  if ($progId) {
    $candidateShellRoots += "Registry::HKEY_CLASSES_ROOT\$progId\shell"
  }
  # common fallback ProgID
  $candidateShellRoots += "Registry::HKEY_CLASSES_ROOT\Unreal.ProjectFile\shell"
  $candidateShellRoots += "Registry::HKEY_CLASSES_ROOT\.uproject\shell"

  foreach ($shellRoot in $candidateShellRoots | Select-Object -Unique) {
    if (-not (Test-Path $shellRoot)) { continue }

    foreach ($verbKey in Get-ChildItem $shellRoot -ErrorAction SilentlyContinue) {
      $cmdKey = Join-Path $verbKey.PSPath "command"
      if (-not (Test-Path $cmdKey)) { continue }

      $cmd = (Get-ItemProperty $cmdKey -ErrorAction SilentlyContinue).'(default)'
      if (-not $cmd) { continue }

      # We only care about verbs that run UnrealVersionSelector.exe /projectfiles.
      if ($cmd -match 'UnrealVersionSelector\.exe"\s+/projectfiles\s+"%1"' -or
        $cmd -match 'UnrealVersionSelector\.exe"\s+/projectfiles') {

        # Extract the exe path between quotes.
        if ($cmd -match '^"(?<exe>[^"]+UnrealVersionSelector\.exe)"') {
          $exe = $Matches.exe
          if (Test-Path $exe) {
            return [pscustomobject]@{
              Path    = $exe
              Source  = "$shellRoot\$($verbKey.PSChildName)"
              Command = $cmd
            }
          }
        }
      }
    }
  }

  return $null
}

function Get-UVSPathFromRegistry {
  $script:LastUVSResolution = Resolve-UVSPathFromRegistry
  if ($script:LastUVSResolution) {
    return [string]$script:LastUVSResolution.Path
  }
  return $null
}

function Resolve-RegenerateFallbackTool([string]$engineRoot) {
  $candidates = @(
    [pscustomobject]@{
      Name = "RunUBT.bat"
      Path = Join-Path $engineRoot "Engine\Build\BatchFiles\RunUBT.bat"
    },
    [pscustomobject]@{
      Name = "Build.bat"
      Path = Join-Path $engineRoot "Engine\Build\BatchFiles\Build.bat"
    }
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate.Path) {
      return [pscustomobject]@{
        Name       = $candidate.Name
        Path       = $candidate.Path
        Candidates = $candidates
      }
    }
  }

  return [pscustomobject]@{
    Name       = $null
    Path       = $null
    Candidates = $candidates
  }
}

function Get-ChangedFiles([string]$oldrev, [string]$newrev) {
  if ([string]::IsNullOrWhiteSpace($oldrev) -or [string]::IsNullOrWhiteSpace($newrev)) { return @() }
  $out = git diff --name-only $oldrev $newrev 2>$null
  if ($LASTEXITCODE -ne 0) { return @() }
  @($out)
}

function Get-RebuildTriggers([string[]]$ChangedFiles) {
  if (-not $ChangedFiles -or $ChangedFiles.Count -eq 0) {
    return @()
  }

  $triggers = @()

  foreach ($f in $ChangedFiles) {
    if ($f -match '^Source/.*\.(h|hpp|cpp|inl)$') { $triggers += $f; continue }
    if ($f -match '\.Build\.cs$') { $triggers += $f; continue }
    if ($f -match '\.Target\.cs$') { $triggers += $f; continue }
    if ($f -match '\.uproject$') { $triggers += $f; continue }
    if ($f -match '^Plugins/.*\.(uplugin|Build\.cs|Target\.cs|h|hpp|cpp)$') {
      $triggers += $f
      continue
    }
  }

  return ($triggers | Sort-Object -Unique)
}

function Show-RebuildTriggers([string[]]$Triggers) {
  if (-not $Triggers -or $Triggers.Count -eq 0) {
    return
  }

  Warn "Structural C++ changes detected in the following files:"
  foreach ($t in $Triggers) {
    Warn " - $t"
  }
}

function Invoke-Regenerate-ProjectFiles(
  [string]$uprojectPath,
  [string]$engineRootForFallback,
  [string]$workspacePathOverride
) {
  $uvs = Get-UVSPathFromRegistry
  if (-not $uvs) {
    Warn "UVS not found via registry; using RunUBT fallback..."
  }
  else {
    $uvsArgs = @("/projectfiles", $uprojectPath)
    Warn "Regenerating project files (context menu UVS)..."
    Info "UVS path: $uvs"
    if ($script:LastUVSResolution -and $script:LastUVSResolution.Source) {
      Info "UVS source: $($script:LastUVSResolution.Source)"
    }
    if ($script:LastUVSResolution -and $script:LastUVSResolution.Command) {
      Info "UVS command: $($script:LastUVSResolution.Command)"
    }
    Info "UVS args: $($uvsArgs -join ' ')"
    Info "UVS cwd : $((Get-Location).Path)"

    $maxAttempts = 2
    if ($env:UE_SYNC_UVS_MAX_ATTEMPTS -as [int]) {
      $maxAttempts = [int]$env:UE_SYNC_UVS_MAX_ATTEMPTS
    }
    if ($maxAttempts -lt 1) {
      $maxAttempts = 1
    }

    $uvsExitCode = -1
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
      try {
        $uvsProcess = Start-Process `
          -FilePath $uvs `
          -ArgumentList @("/projectfiles", "`"$uprojectPath`"") `
          -WorkingDirectory (Split-Path -Path $uprojectPath -Parent) `
          -Wait `
          -PassThru `
          -ErrorAction Stop
        $uvsExitCode = [int]$uvsProcess.ExitCode
      }
      catch {
        Warn "UVS invocation failed on attempt $attempt/${maxAttempts}: $($_.Exception.Message)"
        $uvsExitCode = -1
      }

      if ($uvsExitCode -eq 0) {
        Success "UVS project-file regeneration succeeded."
        return
      }

      if ($attempt -lt $maxAttempts) {
        Warn "UVS returned non-zero exit ($uvsExitCode) on attempt $attempt/$maxAttempts. Retrying..."
        Start-Sleep -Milliseconds 300
      }
    }

    Warn "UVS failed (exit $uvsExitCode) after $maxAttempts attempt(s). Falling back to RunUBT..."
  }

  if (-not $engineRootForFallback) {
    Warn "Engine root was not pre-resolved for fallback. Resolving now..."
    $engineRootForFallback = Resolve-EngineRootForBuild $workspacePathOverride $uprojectPath
  }
  Info "Engine (fallback): $engineRootForFallback"

  $fallbackTool = Resolve-RegenerateFallbackTool $engineRootForFallback
  if (-not $fallbackTool.Path) {
    $candidateText = $fallbackTool.Candidates | ForEach-Object { "- $($_.Name): $($_.Path)" }
    throw @"
Cannot run project-file fallback. No supported tool was found under engine root:
$engineRootForFallback

Checked:
$($candidateText -join "`n")
"@
  }

  $regenLogDir = Join-Path (Get-Location).Path "Intermediate\UnrealSync"
  New-Item -ItemType Directory -Force -Path $regenLogDir | Out-Null
  $regenLog = Join-Path $regenLogDir ("ProjectFiles-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))

  $fallbackArgs = @(
    "-projectfiles",
    "-vscode",
    "-project=$uprojectPath",
    "-game",
    "-engine",
    "-log=$regenLog"
  )
  if ($fallbackTool.Name -eq "RunUBT.bat") {
    $fallbackArgs += "-dotnet"
  }

  Warn "Regenerating project files (RunUBT fallback via $($fallbackTool.Name))..."
  Info "Fallback tool: $($fallbackTool.Path)"
  Info "Fallback args: $($fallbackArgs -join ' ')"
  & $fallbackTool.Path @fallbackArgs | Out-Host

  if ($LASTEXITCODE -ne 0) {
    throw "RunUBT projectfiles failed (exit $LASTEXITCODE). See log: $regenLog"
  }

  Success "Fallback project-file regeneration succeeded."
}


function Build-Editor([string]$engineRoot, [string]$uprojectPath, [string]$projectName, [string]$platform, [string]$config) {
  $buildBat = Join-Path $engineRoot "Engine\Build\BatchFiles\Build.bat"
  if (-not (Test-Path $buildBat)) { throw "Build.bat not found: $buildBat" }

  $target = "${projectName}Editor"
  Warn "Building $target ($platform $config) using engine root: $engineRoot"
  & $buildBat $target $platform $config -Project="`"$uprojectPath`"" -WaitMutex | Out-Host
}

# ---- Main ----
$manual = $Force -or $CleanSaved -or $CleanCache -or $NoRegen -or $NoBuild

# If invoked from hook, only run on branch checkouts.
if (-not $manual -and $Flag -ne 1) { 
  exit 0 
}

# Rebase can execute hooks at many internal steps. Keep hook execution silent there.
$reflogAction = [string]$env:GIT_REFLOG_ACTION
if (-not $manual -and $reflogAction -match 'rebase') {
  exit 0
}

# Skip silently during active merge/rebase contexts when running from hooks.
if (-not $manual) {
  $gitDir = (git rev-parse --git-dir 2>$null | Select-Object -First 1).Trim()
  if ([string]::IsNullOrWhiteSpace($gitDir)) { $gitDir = ".git" }
  if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
    $gitDir = Join-Path (Get-Location).Path $gitDir
  }

  if (
      (Test-Path (Join-Path $gitDir "rebase-apply")) -or
      (Test-Path (Join-Path $gitDir "rebase-merge")) -or
      (Test-Path (Join-Path $gitDir "MERGE_HEAD")) -or
      (Test-Path (Join-Path $gitDir "CHERRY_PICK_HEAD")) -or
      (Test-Path (Join-Path $gitDir "REVERT_HEAD"))
    ) {
    exit 0
  }
}

$triggerFiles = @()
if (-not $manual) {
  $changed = Get-ChangedFiles $OldRev $NewRev
  $triggerFiles = Get-RebuildTriggers $changed
  if (-not $Force -and $triggerFiles.Count -eq 0) {
    # No structural trigger => no-op, keep hook output clean.
    exit 0
  }
}

$uprojectPath = Get-UProjectPath
$projectName = Get-ProjectName $uprojectPath

Info "UProject Path: $uprojectPath"
if (-not $manual) {
  Info "Checking for structural C++ changes between $OldRev and $NewRev..."
  Show-RebuildTriggers $triggerFiles
}

if (-not $manual) {
  $rootInteractive = Test-EnvTrue $env:UE_SYNC_ROOT_INTERACTIVE
  $hookHasTty = Test-EnvTrue $env:UE_SYNC_HOOK_HAS_TTY
  $isNonInteractive = $NonInteractive.IsPresent
  $promptRequested = $false
  if (-not $isNonInteractive) {
    if ($rootInteractive -and -not $hookHasTty) {
      Warn "Interactive root command detected but this hook has no terminal access. Skipping UE Sync to avoid an unconfirmed rebuild."
      exit 0
    }
    elseif ($rootInteractive) {
      # Hook layer captured the original git command as interactive.
      # Prefer prompting even if this child process has detached stdio.
      $promptRequested = $true
    }
    elseif (-not (Test-CanPrompt)) {
      $isNonInteractive = $true
    }
  }

  if (-not $isNonInteractive) {
    Info "Would you like to proceed with regenerating project files and building the editor? (y/n)"
    try {
      $response = Read-Host
    }
    catch {
      if ($promptRequested) {
        Warn "Interactive root command detected but prompt could not be shown. Skipping UE Sync to avoid an unconfirmed rebuild."
        exit 0
      }
      $isNonInteractive = $true
      $response = $null
    }

    if ($promptRequested -and [string]::IsNullOrWhiteSpace([string]$response)) {
      Warn "Interactive root command detected but no input was received. Skipping UE Sync to avoid an unconfirmed rebuild."
      exit 0
    }
  }

  if (-not $isNonInteractive) {
    $responseText = ([string]$response).Trim()
    if ($responseText -ne 'y' -and $responseText -ne 'Y') {
      Warn "User chose not to proceed. Exiting."
      exit 0
    }
  }
  else {
    Warn "Non-interactive execution detected; proceeding without confirmation."
  }
}
else {
  $isNonInteractive = $NonInteractive.IsPresent
  if (-not $isNonInteractive) {
    $isNonInteractive = -not (Test-CanPrompt)
  }
}

Info "Cleaning generated folders..."
if ($DryRun) {
  Info "DryRun enabled. Skipping cleanup/regeneration/build."
  exit 0
}

[void](Remove-IfExists -Path "Binaries" -NonInteractive:$isNonInteractive)
[void](Remove-IfExists -Path "Intermediate" -NonInteractive:$isNonInteractive)
if ($CleanCache) { [void](Remove-IfExists -Path "DerivedDataCache" -NonInteractive:$isNonInteractive) }
if ($CleanSaved) { [void](Remove-IfExists -Path "Saved" -NonInteractive:$isNonInteractive) }

$engineRoot = $null
if (-not $NoBuild) {
  $engineRoot = Resolve-EngineRootForBuild $WorkspacePath $uprojectPath
  Info "Engine (build): $engineRoot"
}

if (-not $NoRegen) {
  Invoke-Regenerate-ProjectFiles $uprojectPath $engineRoot $WorkspacePath
}
else {
  Warn "Skipping project file regeneration..."
}

if (-not $NoBuild) {
  Build-Editor $engineRoot $uprojectPath $projectName $Platform $Config
}
else {
  Warn "Skipping build..."
}

Success "Done."
exit 0
