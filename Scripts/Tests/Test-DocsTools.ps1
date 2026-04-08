[CmdletBinding()]
param(
  [switch]$NoCleanup,
  [switch]$FailFast
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = ((git rev-parse --show-toplevel 2>$null) | Select-Object -First 1).Trim()
if (-not $repoRoot) { throw "Not inside a git repository." }
Set-Location $repoRoot

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$resultsDir = Join-Path $repoRoot "Scripts\Tests\Test-DocsToolsResults"
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
$logPath = Join-Path $resultsDir "DocsToolsTest-$stamp.log"
$tempRoot = Join-Path $resultsDir "scratch-$stamp"
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$script:DocsToolsScriptPath = Join-Path $repoRoot "Scripts\Docs\DocsTools.ps1"
$script:PassCount = 0
$script:FailCount = 0
$script:WarnCount = 0
$script:SkipCount = 0
$script:CleanupRan = $false

function Write-Log {
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
    [ConsoleColor]$Color = [ConsoleColor]::Gray
  )

  Write-Host $Message -ForegroundColor $Color
  Add-Content -LiteralPath $logPath -Value $Message -Encoding UTF8
}

function Step([string]$Title) {
  Write-Log ""
  Write-Log "============================================================" DarkGray
  Write-Log $Title DarkGray
  Write-Log "============================================================" DarkGray
}

function Pass([string]$Name, [string]$Detail) {
  $script:PassCount++
  Write-Log "[PASS] $Name - $Detail" Green
}

function Fail([string]$Name, [string]$Detail) {
  $script:FailCount++
  Write-Log "[FAIL] $Name - $Detail" Red
  if ($FailFast) { throw "FAILFAST" }
}

function Assert-Condition {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][bool]$Condition,
    [string]$PassDetail = "condition is true",
    [string]$FailDetail = "condition is false"
  )

  if ($Condition) {
    Pass $Name $PassDetail
    return
  }

  Fail $Name $FailDetail
}

function Assert-TextContains {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory)][string]$Needle
  )

  if ([string]::Concat($Text).Contains($Needle)) {
    Pass $Name "matched: $Needle"
    return
  }

  Fail $Name "missing expected text: $Needle"
}

function Assert-TextNotContains {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory)][string]$Needle
  )

  if (-not [string]::Concat($Text).Contains($Needle)) {
    Pass $Name "did not match: $Needle"
    return
  }

  Fail $Name "unexpected text found: $Needle"
}

function Write-Utf8NoBomFile {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function New-ScratchPath([string]$Name) {
  return (Join-Path $tempRoot $Name)
}

function New-MinimalDocsRepo {
  param([Parameter(Mandatory)][string]$Name)

  $scratchRepo = New-ScratchPath $Name
  New-Item -ItemType Directory -Force -Path (Join-Path $scratchRepo "Docs") | Out-Null
  $scratchWebsiteRoot = Join-Path $scratchRepo "website"
  New-Item -ItemType Directory -Force -Path $scratchWebsiteRoot | Out-Null

  $readmeContent = @'
---
title: Overview
slug: /
sidebar_position: 1
---

# Overview

Minimal docs root for docs-tools testing.
'@
  Write-Utf8NoBomFile -Path (Join-Path $scratchRepo "Docs\README.md") -Content $readmeContent

  $packageSource = Join-Path $repoRoot "website\package.json"
  if (Test-Path -LiteralPath $packageSource) {
    Copy-Item -LiteralPath $packageSource -Destination (Join-Path $scratchWebsiteRoot "package.json") -Force
  }

  return $scratchRepo
}

function New-StubToolset {
  param(
    [Parameter(Mandatory)][string]$Name,
    [string[]]$CodeExtensions = @()
  )

  $stubRoot = New-ScratchPath $Name
  New-Item -ItemType Directory -Force -Path $stubRoot | Out-Null

  $commandLog = Join-Path $stubRoot "stub-commands.log"
  Write-Utf8NoBomFile -Path $commandLog -Content ""

  $codeLines = @(
    "@echo off"
    'if "%~1"=="--list-extensions" ('
  )
  foreach ($extensionId in @($CodeExtensions)) {
    $codeLines += "  echo $extensionId"
  }
  $codeLines += @(
    "  exit /b 0"
    ")"
    '>> "%STUB_LOG%" echo code %*'
    "exit /b 0"
  )
  Write-Utf8NoBomFile -Path (Join-Path $stubRoot "code.cmd") -Content ($codeLines -join "`r`n")

  $npmLines = @(
    "@echo off"
    '>> "%STUB_LOG%" echo npm %*'
    'if "%~1"=="run" if "%~2"=="start" if /i "%STUB_NPM_START_MODE%"=="sleep" ('
    '  ping -n 60 127.0.0.1 >nul'
    ')'
    "exit /b 0"
  )
  Write-Utf8NoBomFile -Path (Join-Path $stubRoot "npm.cmd") -Content ($npmLines -join "`r`n")

  return [pscustomobject]@{
    StubRoot = $stubRoot
    CommandLog = $commandLog
  }
}

function Invoke-DocsToolsCommand {
  param(
    [Parameter(Mandatory)][string]$ScratchRepoRoot,
    [Parameter(Mandatory)][string[]]$CliArgs,
    [Parameter(Mandatory)]$Toolset,
    [Parameter(Mandatory)][string]$SandboxRoot,
    [hashtable]$ExtraEnv = @{}
  )

  $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
  $sandboxLocalAppData = Join-Path $SandboxRoot "LocalAppData"
  $sandboxUserProfile = Join-Path $SandboxRoot "UserProfile"
  $sandboxTemp = Join-Path $SandboxRoot "Temp"
  foreach ($path in @($sandboxLocalAppData, $sandboxUserProfile, $sandboxTemp)) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
  }

  $pathSegments = @(
    $Toolset.StubRoot,
    (Join-Path $env:SystemRoot "System32"),
    $env:SystemRoot
  ) | Where-Object { $_ -and $_.Trim() -ne "" }

  $previousEnv = @{
    Path = $env:Path
    LOCALAPPDATA = $env:LOCALAPPDATA
    USERPROFILE = $env:USERPROFILE
    TEMP = $env:TEMP
    TMP = $env:TMP
    STUB_LOG = $env:STUB_LOG
    STUB_NPM_START_MODE = $env:STUB_NPM_START_MODE
  }

  try {
    $env:Path = ($pathSegments -join ';')
    $env:LOCALAPPDATA = $sandboxLocalAppData
    $env:USERPROFILE = $sandboxUserProfile
    $env:TEMP = $sandboxTemp
    $env:TMP = $sandboxTemp
    $env:STUB_LOG = $Toolset.CommandLog
    foreach ($entry in $ExtraEnv.GetEnumerator()) {
      Set-Item -Path ("Env:{0}" -f $entry.Key) -Value ([string]$entry.Value)
    }

    $allArgs = @(
      "-NoLogo",
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", $script:DocsToolsScriptPath,
      "-RepoRoot", $ScratchRepoRoot
    ) + @($CliArgs)

    $output = @(& $pwshPath @allArgs 2>&1)
    $exitCode = $LASTEXITCODE

    return [pscustomobject]@{
      ExitCode = $exitCode
      OutputLines = @($output | ForEach-Object { "$_" })
      OutputText = (($output | ForEach-Object { "$_" }) -join "`n")
      SandboxLocalAppData = $sandboxLocalAppData
      SandboxUserProfile = $sandboxUserProfile
      SandboxTemp = $sandboxTemp
    }
  }
  finally {
    $env:Path = $previousEnv.Path
    $env:LOCALAPPDATA = $previousEnv.LOCALAPPDATA
    $env:USERPROFILE = $previousEnv.USERPROFILE
    $env:TEMP = $previousEnv.TEMP
    $env:TMP = $previousEnv.TMP
    $env:STUB_LOG = $previousEnv.STUB_LOG
    $env:STUB_NPM_START_MODE = $previousEnv.STUB_NPM_START_MODE
  }
}

function Restore-State {
  if ($script:CleanupRan) { return }
  $script:CleanupRan = $true

  if ($NoCleanup) {
    Write-Log "[WARN] Cleanup - NoCleanup set; leaving scratch files in place." Yellow
    return
  }

  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

try {
  Step "Docs Tools Tests ($stamp)"
  Write-Log "Repo: $repoRoot" Cyan
  Write-Log "Log : $logPath" Cyan

  Assert-Condition "script exists" (Test-Path -LiteralPath $script:DocsToolsScriptPath) "DocsTools.ps1 found"

  Step "Case 1: Help output lists the supported commands"
  $helpRepo = New-MinimalDocsRepo -Name "repo-help"
  $helpToolset = New-StubToolset -Name "toolset-help"
  $helpResult = Invoke-DocsToolsCommand -ScratchRepoRoot $helpRepo -CliArgs @("help") -Toolset $helpToolset -SandboxRoot (New-ScratchPath "sandbox-help")
  Assert-Condition "case1 help exits cleanly" ($helpResult.ExitCode -eq 0) "exit code=0" "exit code=$($helpResult.ExitCode)"
  Assert-TextContains "case1 help shows new-section" $helpResult.OutputText "docs-tools new-section <SectionPath>"
  Assert-TextContains "case1 help shows new-page" $helpResult.OutputText "docs-tools new-page <SectionPath> <PageName>"
  Assert-TextContains "case1 help shows start" $helpResult.OutputText "docs-tools start [docusaurus-start args]"
  Assert-TextContains "case1 help shows stop" $helpResult.OutputText "docs-tools stop"
  Assert-TextContains "case1 help shows docusaurus passthrough" $helpResult.OutputText "docs-tools docusaurus <args...>"
  Assert-TextContains "case1 help shows install-bridge" $helpResult.OutputText "docs-tools install-bridge"

  Step "Case 2: new-section scaffolds a section and skips TOC without the bridge"
  $noTocRepo = New-MinimalDocsRepo -Name "repo-no-toc"
  $noTocToolset = New-StubToolset -Name "toolset-no-toc"
  $newSectionResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $noTocRepo `
    -CliArgs @("new-section", "GameDesign", "-Title", "Game Design", "-Position", "9") `
    -Toolset $noTocToolset `
    -SandboxRoot (New-ScratchPath "sandbox-no-toc")
  $sectionReadme = Join-Path $noTocRepo "Docs\GameDesign\README.md"
  $sectionCategory = Join-Path $noTocRepo "Docs\GameDesign\_category_.json"
  $sectionReadmeText = Get-Content -LiteralPath $sectionReadme -Raw
  $sectionCategoryText = Get-Content -LiteralPath $sectionCategory -Raw
  Assert-Condition "case2 new-section exits cleanly" ($newSectionResult.ExitCode -eq 0) "exit code=0" "exit code=$($newSectionResult.ExitCode)"
  Assert-Condition "case2 section readme created" (Test-Path -LiteralPath $sectionReadme) "README.md created"
  Assert-Condition "case2 category metadata created" (Test-Path -LiteralPath $sectionCategory) "_category_.json created"
  Assert-TextContains "case2 output confirms skipped toc" $newSectionResult.OutputText "TOC generation skipped."
  Assert-TextContains "case2 readme has section slug" $sectionReadmeText "slug: /game-design"
  Assert-TextContains "case2 readme has overview heading" $sectionReadmeText "## Overview"
  Assert-TextNotContains "case2 readme omits toc marker" $sectionReadmeText "<!-- docs-tools-toc -->"
  Assert-TextContains "case2 category label" $sectionCategoryText '"label": "Game Design"'
  Assert-TextContains "case2 category position" $sectionCategoryText '"position": 9'
  Assert-TextContains "case2 category doc link" $sectionCategoryText '"id": "GameDesign/README"'

  Step "Case 2b: new-section auto-assigns the next sidebar position"
  $autoSectionRepo = New-MinimalDocsRepo -Name "repo-auto-section-position"
  $autoSectionToolset = New-StubToolset -Name "toolset-auto-section-position"
  $autoSectionResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $autoSectionRepo `
    -CliArgs @("new-section", "Systems") `
    -Toolset $autoSectionToolset `
    -SandboxRoot (New-ScratchPath "sandbox-auto-section-position")
  $autoSectionCategoryText = Get-Content -LiteralPath (Join-Path $autoSectionRepo "Docs\Systems\_category_.json") -Raw
  Assert-Condition "case2b new-section exits cleanly" ($autoSectionResult.ExitCode -eq 0) "exit code=0" "exit code=$($autoSectionResult.ExitCode)"
  Assert-TextContains "case2b default section position increments" $autoSectionCategoryText '"position": 2'

  Step "Case 3: new-page scaffolds a page and skips TOC without the bridge"
  $newPageResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $noTocRepo `
    -CliArgs @("new-page", "GameDesign", "Fear-Loop", "-Title", "Fear Loop", "-Position", "2") `
    -Toolset $noTocToolset `
    -SandboxRoot (New-ScratchPath "sandbox-new-page-no-toc")
  $pagePath = Join-Path $noTocRepo "Docs\GameDesign\Fear-Loop.md"
  $pageText = Get-Content -LiteralPath $pagePath -Raw
  Assert-Condition "case3 new-page exits cleanly" ($newPageResult.ExitCode -eq 0) "exit code=0" "exit code=$($newPageResult.ExitCode)"
  Assert-Condition "case3 page created" (Test-Path -LiteralPath $pagePath) "Fear-Loop.md created"
  Assert-TextContains "case3 output confirms skipped toc" $newPageResult.OutputText "TOC generation skipped."
  Assert-TextContains "case3 page slug" $pageText "slug: /game-design/fear-loop"
  Assert-TextContains "case3 page position" $pageText "sidebar_position: 2"
  Assert-TextNotContains "case3 page omits toc marker" $pageText "<!-- docs-tools-toc -->"

  Step "Case 3b: new-page auto-assigns the next sidebar position"
  $autoPageResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $noTocRepo `
    -CliArgs @("new-page", "GameDesign", "Escalation-Loop") `
    -Toolset $noTocToolset `
    -SandboxRoot (New-ScratchPath "sandbox-auto-page-position")
  $autoPageText = Get-Content -LiteralPath (Join-Path $noTocRepo "Docs\GameDesign\Escalation-Loop.md") -Raw
  Assert-Condition "case3b new-page exits cleanly" ($autoPageResult.ExitCode -eq 0) "exit code=0" "exit code=$($autoPageResult.ExitCode)"
  Assert-TextContains "case3b default page position increments" $autoPageText "sidebar_position: 3"

  Step "Case 4: install-bridge copies the optional VS Code bridge"
  $bridgeToolset = New-StubToolset -Name "toolset-install-bridge" -CodeExtensions @("yzhang.markdown-all-in-one")
  $bridgeRepo = New-MinimalDocsRepo -Name "repo-install-bridge"
  $installBridgeResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $bridgeRepo `
    -CliArgs @("install-bridge") `
    -Toolset $bridgeToolset `
    -SandboxRoot (New-ScratchPath "sandbox-install-bridge")
  $bridgeInstallPath = Join-Path $installBridgeResult.SandboxUserProfile ".vscode\extensions\rim28.scarebandb-docs-tools-bridge-0.0.1"
  Assert-Condition "case4 install-bridge exits cleanly" ($installBridgeResult.ExitCode -eq 0) "exit code=0" "exit code=$($installBridgeResult.ExitCode)"
  Assert-Condition "case4 bridge folder created" (Test-Path -LiteralPath $bridgeInstallPath) "bridge extension copied"
  Assert-Condition "case4 bridge package copied" (Test-Path -LiteralPath (Join-Path $bridgeInstallPath "package.json")) "package.json copied"
  Assert-Condition "case4 bridge code copied" (Test-Path -LiteralPath (Join-Path $bridgeInstallPath "extension.js")) "extension.js copied"
  Assert-TextContains "case4 output mentions markdown extension" $installBridgeResult.OutputText "Markdown All in One is already installed."

  Step "Case 5: start launches a background server and stop kills it"
  $startStopRepo = New-MinimalDocsRepo -Name "repo-start-stop"
  $startStopToolset = New-StubToolset -Name "toolset-start-stop"
  $startStopSandbox = New-ScratchPath "sandbox-start-stop"
  $startResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $startStopRepo `
    -CliArgs @("start", "--port", "3001") `
    -Toolset $startStopToolset `
    -SandboxRoot $startStopSandbox `
    -ExtraEnv @{ STUB_NPM_START_MODE = "sleep" }
  $serverStateFiles = @(Get-ChildItem -Path (Join-Path $startResult.SandboxTemp "scarebandb-docs-tools") -Recurse -Filter docs-server.json -ErrorAction SilentlyContinue)
  $serverState = Get-Content -LiteralPath $serverStateFiles[0].FullName -Raw | ConvertFrom-Json
  $startStubLog = Get-Content -LiteralPath $startStopToolset.CommandLog -Raw
  Assert-Condition "case5 start exits cleanly" ($startResult.ExitCode -eq 0) "exit code=0" "exit code=$($startResult.ExitCode)"
  Assert-TextContains "case5 output confirms background start" $startResult.OutputText "Started docs dev server in the background"
  Assert-TextContains "case5 output includes custom port url" $startResult.OutputText "http://localhost:3001/docs/"
  Assert-Condition "case5 server state file created" ($serverStateFiles.Count -eq 1) "docs-server.json created"
  Assert-TextContains "case5 npm start was invoked" $startStubLog "npm run start -- --port 3001"
  $stopResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $startStopRepo `
    -CliArgs @("stop") `
    -Toolset $startStopToolset `
    -SandboxRoot $startStopSandbox
  Assert-Condition "case5 stop exits cleanly" ($stopResult.ExitCode -eq 0) "exit code=0" "exit code=$($stopResult.ExitCode)"
  Assert-Condition "case5 output confirms stop handling" (
    $stopResult.OutputText.Contains("Stopped docs dev server") -or
    $stopResult.OutputText.Contains("Removed stale docs dev server state")
  ) "stop command reported a handled shutdown path"
  Assert-Condition "case5 state file removed after stop" (-not (Test-Path -LiteralPath $serverStateFiles[0].FullName)) "docs-server.json removed"
  Assert-Condition "case5 server pid stopped" (-not (Get-Process -Id $serverState.processId -ErrorAction SilentlyContinue)) "process $($serverState.processId) stopped"

  Step "Case 6: docs-tools can invoke other website package scripts"
  $scriptRepo = New-MinimalDocsRepo -Name "repo-script-passthrough"
  $scriptToolset = New-StubToolset -Name "toolset-script-passthrough"
  $scriptResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $scriptRepo `
    -CliArgs @("write-heading-ids", "--dry-run") `
    -Toolset $scriptToolset `
    -SandboxRoot (New-ScratchPath "sandbox-script-passthrough")
  $scriptStubLog = Get-Content -LiteralPath $scriptToolset.CommandLog -Raw
  Assert-Condition "case6 passthrough command exits cleanly" ($scriptResult.ExitCode -eq 0) "exit code=0" "exit code=$($scriptResult.ExitCode)"
  Assert-TextContains "case6 npm script was invoked" $scriptStubLog "npm run write-heading-ids -- --dry-run"

  Step "Case 7: new-page queues a TOC request when the optional bridge is available"
  $tocRepo = New-MinimalDocsRepo -Name "repo-toc"
  New-Item -ItemType Directory -Force -Path (Join-Path $tocRepo "Docs\GameDesign") | Out-Null
  $tocToolset = New-StubToolset -Name "toolset-toc" -CodeExtensions @(
    "yzhang.markdown-all-in-one",
    "rim28.scarebandb-docs-tools-bridge"
  )
  $tocResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $tocRepo `
    -CliArgs @("new-page", "GameDesign", "Scare-Curve", "-Title", "Scare Curve", "-Position", "3") `
    -Toolset $tocToolset `
    -SandboxRoot (New-ScratchPath "sandbox-toc")
  $tocPagePath = Join-Path $tocRepo "Docs\GameDesign\Scare-Curve.md"
  $tocPageText = Get-Content -LiteralPath $tocPagePath -Raw
  $tocRequestFiles = @(Get-ChildItem -Path (Join-Path $tocResult.SandboxTemp "scarebandb-docs-tools") -Recurse -Filter *.json -ErrorAction SilentlyContinue)
  $stubLogText = Get-Content -LiteralPath $tocToolset.CommandLog -Raw
  Assert-Condition "case7 toc-ready new-page exits cleanly" ($tocResult.ExitCode -eq 0) "exit code=0" "exit code=$($tocResult.ExitCode)"
  Assert-TextContains "case7 output confirms queued toc" $tocResult.OutputText "TOC request queued through the VS Code bridge."
  Assert-TextContains "case7 page contains toc marker" $tocPageText "<!-- docs-tools-toc -->"
  Assert-Condition "case7 request json created" ($tocRequestFiles.Count -ge 1) "request file count=$($tocRequestFiles.Count)" "expected a queued request file"
  Assert-TextContains "case7 code cli was asked to open repo" $stubLogText "code --reuse-window"

  Step "Case 8: check validates docs and runs the Docusaurus build"
  $checkRepo = New-MinimalDocsRepo -Name "repo-check-pass"
  $checkToolset = New-StubToolset -Name "toolset-check-pass"
  $checkResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $checkRepo `
    -CliArgs @("check") `
    -Toolset $checkToolset `
    -SandboxRoot (New-ScratchPath "sandbox-check-pass")
  $checkStubLog = Get-Content -LiteralPath $checkToolset.CommandLog -Raw
  Assert-Condition "case8 check exits cleanly" ($checkResult.ExitCode -eq 0) "exit code=0" "exit code=$($checkResult.ExitCode)"
  Assert-TextContains "case8 output confirms pass" $checkResult.OutputText "Docs check passed."
  Assert-TextContains "case8 npm build was invoked" $checkStubLog "npm run build"

  Step "Case 9: check rejects invalid slugs before attempting a build"
  $badSlugRepo = New-MinimalDocsRepo -Name "repo-check-bad-slug"
  $badSlugToolset = New-StubToolset -Name "toolset-check-bad-slug"
  $badDocPath = Join-Path $badSlugRepo "Docs\Bad-Slug.md"
  $badDocContent = @'
---
title: Bad Slug
slug: /docs/bad-slug
---

# Bad Slug
'@
  Write-Utf8NoBomFile -Path $badDocPath -Content $badDocContent
  $badSlugResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $badSlugRepo `
    -CliArgs @("check") `
    -Toolset $badSlugToolset `
    -SandboxRoot (New-ScratchPath "sandbox-check-bad-slug")
  $badSlugStubLog = Get-Content -LiteralPath $badSlugToolset.CommandLog -Raw
  Assert-Condition "case9 check fails for /docs/ slug" ($badSlugResult.ExitCode -ne 0) "exit code=$($badSlugResult.ExitCode)" "expected non-zero exit code"
  Assert-TextContains "case9 output explains bad slug" $badSlugResult.OutputText "Slug should not start with /docs/:"
  Assert-TextNotContains "case9 npm build not invoked on validation failure" $badSlugStubLog "npm run build"

  Step "Case 10: check rejects unprocessed TOC markers"
  $markerRepo = New-MinimalDocsRepo -Name "repo-check-toc-marker"
  $markerToolset = New-StubToolset -Name "toolset-check-toc-marker"
  $markerDocPath = Join-Path $markerRepo "Docs\Marker.md"
  $markerDocContent = @'
---
title: Marker
slug: /marker
---

# Marker

<!-- docs-tools-toc -->
'@
  Write-Utf8NoBomFile -Path $markerDocPath -Content $markerDocContent
  $markerResult = Invoke-DocsToolsCommand `
    -ScratchRepoRoot $markerRepo `
    -CliArgs @("check") `
    -Toolset $markerToolset `
    -SandboxRoot (New-ScratchPath "sandbox-check-toc-marker")
  Assert-Condition "case10 check fails for unprocessed toc marker" ($markerResult.ExitCode -ne 0) "exit code=$($markerResult.ExitCode)" "expected non-zero exit code"
  Assert-TextContains "case10 output explains toc marker" $markerResult.OutputText "Unprocessed TOC marker remains in:"

  Step "Summary"
  Write-Log ("PASS={0} FAIL={1} WARN={2} SKIP={3}" -f $script:PassCount, $script:FailCount, $script:WarnCount, $script:SkipCount) Cyan
  if ($script:FailCount -eq 0) {
    Write-Log "Docs tools tests passed." Green
  }
  else {
    Write-Log "Docs tools tests failed." Red
    exit 1
  }
}
catch {
  if ($_.Exception.Message -ne "FAILFAST") {
    Write-Log "[FATAL] $($_.Exception.Message)" Red
  }
  Write-Log ("PASS={0} FAIL={1} WARN={2} SKIP={3}" -f $script:PassCount, $script:FailCount, $script:WarnCount, $script:SkipCount) Cyan
  if ($script:FailCount -eq 0) { $script:FailCount = 1 }
  exit 1
}
finally {
  Restore-State
  Write-Log ""
  Write-Log "Log saved: $logPath" Cyan
}
