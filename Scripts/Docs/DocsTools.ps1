[CmdletBinding()]
param(
  [string]$RepoRoot,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$CommandArgs
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$script:DocsToolsBridgeExtensionId = "rim28.scarebandb-docs-tools-bridge"
$script:MarkdownAllInOneExtensionId = "yzhang.markdown-all-in-one"
$script:TocMarker = "<!-- docs-tools-toc -->"
$script:CodeExtensionList = $null
$script:CodeCliPath = $null
$script:WebsitePackageScriptNames = $null

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

function Get-DocsToolsRepoRoot {
  param([string]$ExplicitRepoRoot)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitRepoRoot)) {
    return [System.IO.Path]::GetFullPath($ExplicitRepoRoot)
  }

  $gitRoot = ((git rev-parse --show-toplevel 2>$null) | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($gitRoot)) {
    throw "docs-tools must be run from inside a git repository or passed -RepoRoot."
  }

  return $gitRoot.Trim()
}

function Get-DocsRoot {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)
  return (Join-Path $ResolvedRepoRoot "Docs")
}

function Get-WebsiteRoot {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)
  return (Join-Path $ResolvedRepoRoot "website")
}

function Get-DocsToolsRuntimeDirectory {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)
  return (Join-Path (Get-BridgeRequestDirectory -ResolvedRepoRoot $ResolvedRepoRoot) "runtime")
}

function Get-DocsServerStatePath {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)
  return (Join-Path (Get-DocsToolsRuntimeDirectory -ResolvedRepoRoot $ResolvedRepoRoot) "docs-server.json")
}

function ConvertTo-CmdArgument {
  param([Parameter(Mandatory)][string]$Value)

  if ($Value -notmatch '[\s"&|<>^]') {
    return $Value
  }

  return '"' + ($Value -replace '"', '""') + '"'
}

function Test-ProcessRunning {
  param([int]$ProcessId)

  if ($ProcessId -le 0) {
    return $false
  }

  try {
    Get-Process -Id $ProcessId -ErrorAction Stop | Out-Null
    return $true
  }
  catch {
    return $false
  }
}

function Get-DescendantProcessId {
  param([int]$RootProcessId)

  if ($RootProcessId -le 0) {
    return $null
  }

  $queue = New-Object System.Collections.Generic.Queue[int]
  $queue.Enqueue($RootProcessId)

  while ($queue.Count -gt 0) {
    $parentId = $queue.Dequeue()

    try {
      $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $parentId" -ErrorAction Stop)
    }
    catch {
      $children = @()
    }

    foreach ($child in $children) {
      $childId = [int]$child.ProcessId
      if (Test-ProcessRunning -ProcessId $childId) {
        return $childId
      }

      $queue.Enqueue($childId)
    }
  }

  return $null
}

function Get-DocsServerState {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  $statePath = Get-DocsServerStatePath -ResolvedRepoRoot $ResolvedRepoRoot
  if (-not (Test-Path -LiteralPath $statePath)) {
    return $null
  }

  return (Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json)
}

function Remove-DocsServerState {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  $statePath = Get-DocsServerStatePath -ResolvedRepoRoot $ResolvedRepoRoot
  if (Test-Path -LiteralPath $statePath) {
    Remove-Item -LiteralPath $statePath -Force
  }
}

function Save-DocsServerState {
  param(
    [Parameter(Mandatory)][string]$ResolvedRepoRoot,
    [Parameter(Mandatory)][object]$State
  )

  $runtimeDir = Get-DocsToolsRuntimeDirectory -ResolvedRepoRoot $ResolvedRepoRoot
  New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

  $statePath = Get-DocsServerStatePath -ResolvedRepoRoot $ResolvedRepoRoot
  $json = $State | ConvertTo-Json -Depth 6
  Write-Utf8NoBomFile -Path $statePath -Content $json
  return $statePath
}

function Get-WebsitePackageScriptNames {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  if ($null -ne $script:WebsitePackageScriptNames) {
    return $script:WebsitePackageScriptNames
  }

  $packagePath = Join-Path (Get-WebsiteRoot -ResolvedRepoRoot $ResolvedRepoRoot) "package.json"
  if (-not (Test-Path -LiteralPath $packagePath)) {
    $script:WebsitePackageScriptNames = @()
    return $script:WebsitePackageScriptNames
  }

  $packageJson = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
  if (-not $packageJson.scripts) {
    $script:WebsitePackageScriptNames = @()
    return $script:WebsitePackageScriptNames
  }

  $script:WebsitePackageScriptNames = @($packageJson.scripts.PSObject.Properties.Name)
  return $script:WebsitePackageScriptNames
}

function Get-DocsToolsHelp {
@"
ScareBandB docs automation.

Usage:
  docs-tools help
  docs-tools new-section <SectionPath> [-Title <title>] [-Position <n>] [-Force] [-NoToc]
  docs-tools new-page <SectionPath> <PageName> [-Title <title>] [-Position <n>] [-Force] [-NoToc]
  docs-tools start [docusaurus-start args]
  docs-tools stop
  docs-tools build
  docs-tools clear
  docs-tools deploy [args]
  docs-tools serve [args]
  docs-tools swizzle [args]
  docs-tools write-translations [args]
  docs-tools write-heading-ids [args]
  docs-tools typecheck
  docs-tools docusaurus <args...>
  docs-tools check
  docs-tools install-bridge

Examples:
  docs-tools new-section GameDesign -Title "Game Design" -Position 9
  docs-tools new-page GameDesign Fear-Loop -Title "Fear Loop" -Position 2
  docs-tools start --port 3001
  docs-tools stop
  docs-tools write-heading-ids
  docs-tools docusaurus docs:version 1.0.0
  docs-tools check
  docs-tools install-bridge

Notes:
  - Docs are authored in Docs/ and rendered by website/.
  - Sidebar structure is autogenerated from Docs/ folder metadata.
  - If -Position is omitted, new pages and sections get the next available
    sidebar position automatically.
  - start runs the Docusaurus dev server in the background; stop kills that
    tracked process tree.
  - All website/package.json scripts are available as docs-tools commands.
  - TOC generation is optional. It runs only when both Markdown All in One and
    the ScareBandB VS Code bridge are installed.
"@
}

function ConvertTo-KebabCase {
  param([Parameter(Mandatory)][string]$Text)

  $value = $Text.Trim()
  $value = $value -creplace '([a-z0-9])([A-Z])', '$1-$2'
  $value = $value -replace '[^A-Za-z0-9]+', '-'
  $value = $value.Trim('-')

  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Could not convert '$Text' into a slug segment."
  }

  return $value.ToLowerInvariant()
}

function ConvertTo-TitleWords {
  param([Parameter(Mandatory)][string]$Text)

  $expanded = $Text.Trim()
  $expanded = $expanded -creplace '([a-z0-9])([A-Z])', '$1 $2'
  $expanded = $expanded -replace '[_\-]+', ' '
  $expanded = $expanded -replace '\s+', ' '
  $expanded = $expanded.Trim()

  if ([string]::IsNullOrWhiteSpace($expanded)) {
    throw "Could not convert '$Text' into a title."
  }

  $textInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
  return $textInfo.ToTitleCase($expanded.ToLowerInvariant())
}

function ConvertTo-FileStem {
  param([Parameter(Mandatory)][string]$Text)

  $expanded = $Text.Trim()
  $expanded = $expanded -replace '\.md$', ''
  $expanded = $expanded -creplace '([a-z0-9])([A-Z])', '$1 $2'
  $expanded = $expanded -replace '[^A-Za-z0-9]+', ' '
  $expanded = $expanded -replace '\s+', ' '
  $expanded = $expanded.Trim()

  if ([string]::IsNullOrWhiteSpace($expanded)) {
    throw "Could not convert '$Text' into a file name."
  }

  $parts = @($expanded.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
  return ($parts | ForEach-Object {
      if ($_.Length -eq 1) { $_.ToUpperInvariant() }
      else { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }
    }) -join '-'
}

function Get-RelativeDocPath {
  param(
    [Parameter(Mandatory)][string]$DocsRoot,
    [Parameter(Mandatory)][string]$FullPath
  )

  $relative = [System.IO.Path]::GetRelativePath($DocsRoot, $FullPath)
  return ($relative -replace '\\', '/')
}

function Get-DocIdForPath {
  param(
    [Parameter(Mandatory)][string]$DocsRoot,
    [Parameter(Mandatory)][string]$FullPath
  )

  $relative = Get-RelativeDocPath -DocsRoot $DocsRoot -FullPath $FullPath
  return ($relative -replace '\.md$', '')
}

function Get-SlugForSectionPath {
  param([Parameter(Mandatory)][string]$SectionPath)

  $segments = @($SectionPath -split '[\\/]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($segments.Count -eq 0) {
    throw "Section path must not be empty."
  }

  $slugSegments = @($segments | ForEach-Object { ConvertTo-KebabCase $_ })
  return "/" + ($slugSegments -join '/')
}

function Get-SlugForPage {
  param(
    [Parameter(Mandatory)][string]$SectionPath,
    [Parameter(Mandatory)][string]$PageName
  )

  $sectionSlug = Get-SlugForSectionPath -SectionPath $SectionPath
  $pageSlug = ConvertTo-KebabCase $PageName
  return "$sectionSlug/$pageSlug"
}

function Parse-SubcommandArguments {
  param(
    [Parameter(Mandatory)][string[]]$Args,
    [string[]]$SwitchNames = @(),
    [string[]]$ValueNames = @()
  )

  $positionals = New-Object System.Collections.Generic.List[string]
  $values = @{}
  $switches = @{}
  $switchSet = @($SwitchNames | ForEach-Object { $_.ToLowerInvariant() })
  $valueSet = @($ValueNames | ForEach-Object { $_.ToLowerInvariant() })

  for ($i = 0; $i -lt $Args.Count; $i++) {
    $token = [string]$Args[$i]
    if ($token.StartsWith('-')) {
      $name = $token.TrimStart('-').ToLowerInvariant()

      if ($switchSet -contains $name) {
        $switches[$name] = $true
        continue
      }

      if ($valueSet -contains $name) {
        if (($i + 1) -ge $Args.Count) {
          throw "Missing value for option '$token'."
        }

        $values[$name] = [string]$Args[$i + 1]
        $i++
        continue
      }

      throw "Unknown option '$token'."
    }

    $positionals.Add($token) | Out-Null
  }

  return [pscustomobject]@{
    Positionals = @($positionals)
    Values = $values
    Switches = $switches
  }
}

function Get-CodeCliPath {
  if ($script:CodeCliPath) {
    return $script:CodeCliPath
  }

  $command = Get-Command code.cmd -ErrorAction SilentlyContinue
  if ($command) {
    $script:CodeCliPath = $command.Source
    return $script:CodeCliPath
  }

  $defaultPath = Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"
  if (Test-Path -LiteralPath $defaultPath) {
    $script:CodeCliPath = $defaultPath
    return $script:CodeCliPath
  }

  return $null
}

function Get-InstalledVSCodeExtensions {
  $codeCliPath = Get-CodeCliPath
  if (-not $codeCliPath) {
    return @()
  }

  if ($null -ne $script:CodeExtensionList) {
    return $script:CodeExtensionList
  }

  $lines = @(& $codeCliPath --list-extensions 2>$null)
  $script:CodeExtensionList = @($lines | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
  return $script:CodeExtensionList
}

function Test-VSCodeExtensionInstalled {
  param([Parameter(Mandatory)][string]$ExtensionId)
  return (Get-InstalledVSCodeExtensions) -contains $ExtensionId
}

function Get-BridgeStatus {
  $codeCliPath = Get-CodeCliPath
  $markdownInstalled = $false
  $bridgeInstalled = $false

  if ($codeCliPath) {
    $markdownInstalled = Test-VSCodeExtensionInstalled -ExtensionId $script:MarkdownAllInOneExtensionId
    $bridgeInstalled = Test-VSCodeExtensionInstalled -ExtensionId $script:DocsToolsBridgeExtensionId
  }

  return [pscustomobject]@{
    CodeCliPath = $codeCliPath
    MarkdownAllInOneInstalled = $markdownInstalled
    BridgeInstalled = $bridgeInstalled
    TocReady = ($codeCliPath -and $markdownInstalled -and $bridgeInstalled)
  }
}

function Get-WorkspaceRequestKey {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  $normalized = [System.IO.Path]::GetFullPath($ResolvedRepoRoot).ToLowerInvariant()
  $sha1 = [System.Security.Cryptography.SHA1]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
    $hash = $sha1.ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
  }
  finally {
    $sha1.Dispose()
  }
}

function Get-BridgeRequestDirectory {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  $workspaceKey = Get-WorkspaceRequestKey -ResolvedRepoRoot $ResolvedRepoRoot
  return (Join-Path ([System.IO.Path]::GetTempPath()) "scarebandb-docs-tools\$workspaceKey")
}

function Queue-TocRequest {
  param(
    [Parameter(Mandatory)][string]$ResolvedRepoRoot,
    [Parameter(Mandatory)][string]$FilePath
  )

  $requestDir = Get-BridgeRequestDirectory -ResolvedRepoRoot $ResolvedRepoRoot
  New-Item -ItemType Directory -Force -Path $requestDir | Out-Null

  $requestObject = [ordered]@{
    version = 1
    action = "createToc"
    workspaceRoot = [System.IO.Path]::GetFullPath($ResolvedRepoRoot)
    filePath = [System.IO.Path]::GetFullPath($FilePath)
    marker = $script:TocMarker
    createdAt = (Get-Date).ToString("o")
  }

  $requestId = "{0}-{1}" -f (Get-Date).ToString("yyyyMMddHHmmss"), ([Guid]::NewGuid().ToString("N"))
  $json = $requestObject | ConvertTo-Json -Depth 5
  $tempPath = Join-Path $requestDir "$requestId.tmp"
  $finalPath = Join-Path $requestDir "$requestId.json"

  Write-Utf8NoBomFile -Path $tempPath -Content $json
  Move-Item -LiteralPath $tempPath -Destination $finalPath -Force

  return $finalPath
}

function Open-PathInVSCode {
  param(
    [Parameter(Mandatory)][string]$ResolvedRepoRoot,
    [Parameter(Mandatory)][string]$FilePath
  )

  $codeCliPath = Get-CodeCliPath
  if (-not $codeCliPath) {
    return $false
  }

  & $codeCliPath --reuse-window $ResolvedRepoRoot | Out-Null
  & $codeCliPath --reuse-window -g "$FilePath:1" | Out-Null
  return $true
}

function Build-SectionReadmeContent {
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Slug,
    [int]$Position,
    [bool]$IncludeToc
  )

  $frontMatter = @(
    "---"
    "title: $Title"
    "slug: $Slug"
  )

  if ($Position -gt 0) {
    $frontMatter += "sidebar_position: $Position"
  }

  $frontMatter += "---"

  $body = @(
    ""
    "# $Title <!-- omit from toc -->"
    ""
  )

  if ($IncludeToc) {
    $body += @(
      "## Table of Contents <!-- omit from toc -->"
      ""
      $script:TocMarker
      ""
    )
  }

  $body += @(
    "## Overview"
    ""
    "Describe this section."
    ""
  )

  return (($frontMatter + $body) -join "`r`n")
}

function Build-PageContent {
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Slug,
    [int]$Position,
    [bool]$IncludeToc
  )

  $frontMatter = @(
    "---"
    "title: $Title"
    "slug: $Slug"
  )

  if ($Position -gt 0) {
    $frontMatter += "sidebar_position: $Position"
  }

  $frontMatter += "---"

  $body = @(
    ""
    "# $Title <!-- omit from toc -->"
    ""
  )

  if ($IncludeToc) {
    $body += @(
      "## Table of Contents <!-- omit from toc -->"
      ""
      $script:TocMarker
      ""
    )
  }

  $body += @(
    "## Overview"
    ""
    "Describe this page."
    ""
  )

  return (($frontMatter + $body) -join "`r`n")
}

function Build-CategoryMetadataContent {
  param(
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][int]$Position,
    [Parameter(Mandatory)][string]$DocId
  )

  $object = [ordered]@{
    label = $Label
    position = $Position
    link = [ordered]@{
      type = "doc"
      id = $DocId
    }
  }

  return (($object | ConvertTo-Json -Depth 5) + "`r`n")
}

function Assert-PathInsideRoot {
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [Parameter(Mandatory)][string]$TargetPath
  )

  $rootFull = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\') + '\'
  $targetFull = [System.IO.Path]::GetFullPath($TargetPath)
  if (-not $targetFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path '$TargetPath' resolves outside the intended root '$RootPath'."
  }
}

function Invoke-NewSection {
  param(
    [Parameter(Mandatory)][string]$ResolvedRepoRoot,
    [Parameter(Mandatory)][string[]]$Args
  )

  $parsed = Parse-SubcommandArguments -Args $Args -SwitchNames @("force", "notoc") -ValueNames @("title", "position")
  if ($parsed.Positionals.Count -lt 1) {
    throw "Usage: docs-tools new-section <SectionPath> [-Title <title>] [-Position <n>] [-Force] [-NoToc]"
  }

  $sectionPath = $parsed.Positionals[0]
  $title = if ($parsed.Values.ContainsKey("title")) { $parsed.Values["title"] } else { ConvertTo-TitleWords ($sectionPath -split '[\\/]' | Select-Object -Last 1) }
  $force = $parsed.Switches.ContainsKey("force")
  $noToc = $parsed.Switches.ContainsKey("notoc")

  $docsRoot = Get-DocsRoot -ResolvedRepoRoot $ResolvedRepoRoot
  $sectionSegments = @($sectionPath -split '[\\/]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($sectionSegments.Count -eq 0) {
    throw "Section path must not be empty."
  }

  $sectionDir = Join-Path $docsRoot ([System.IO.Path]::Combine($sectionSegments))
  Assert-PathInsideRoot -RootPath $docsRoot -TargetPath $sectionDir
  $position = if ($parsed.Values.ContainsKey("position")) { [int]$parsed.Values["position"] } else { Get-NextSectionPosition -DocsRoot $docsRoot -SectionPath $sectionPath }

  $readmePath = Join-Path $sectionDir "README.md"
  $categoryPath = Join-Path $sectionDir "_category_.json"
  $docSlug = Get-SlugForSectionPath -SectionPath $sectionPath
  $bridgeStatus = Get-BridgeStatus
  $includeToc = (-not $noToc) -and $bridgeStatus.TocReady

  if ((Test-Path -LiteralPath $sectionDir) -and (-not $force)) {
    throw "Section directory already exists: $sectionDir"
  }

  New-Item -ItemType Directory -Force -Path $sectionDir | Out-Null

  $readmeContent = Build-SectionReadmeContent -Title $title -Slug $docSlug -Position 1 -IncludeToc:$includeToc
  $docId = Get-DocIdForPath -DocsRoot $docsRoot -FullPath $readmePath
  $categoryContent = Build-CategoryMetadataContent -Label $title -Position $position -DocId $docId

  Write-Utf8NoBomFile -Path $readmePath -Content $readmeContent
  Write-Utf8NoBomFile -Path $categoryPath -Content $categoryContent

  if ($includeToc) {
    $null = Queue-TocRequest -ResolvedRepoRoot $ResolvedRepoRoot -FilePath $readmePath
    [void](Open-PathInVSCode -ResolvedRepoRoot $ResolvedRepoRoot -FilePath $readmePath)
  }

  [pscustomobject]@{
    Command = "new-section"
    Path = $readmePath
    CategoryPath = $categoryPath
    TocQueued = $includeToc
    BridgeStatus = $bridgeStatus
  }
}

function Invoke-NewPage {
  param(
    [Parameter(Mandatory)][string]$ResolvedRepoRoot,
    [Parameter(Mandatory)][string[]]$Args
  )

  $parsed = Parse-SubcommandArguments -Args $Args -SwitchNames @("force", "notoc") -ValueNames @("title", "position")
  if ($parsed.Positionals.Count -lt 2) {
    throw "Usage: docs-tools new-page <SectionPath> <PageName> [-Title <title>] [-Position <n>] [-Force] [-NoToc]"
  }

  $sectionPath = $parsed.Positionals[0]
  $pageName = $parsed.Positionals[1]
  $title = if ($parsed.Values.ContainsKey("title")) { $parsed.Values["title"] } else { ConvertTo-TitleWords $pageName }
  $force = $parsed.Switches.ContainsKey("force")
  $noToc = $parsed.Switches.ContainsKey("notoc")

  $docsRoot = Get-DocsRoot -ResolvedRepoRoot $ResolvedRepoRoot
  $sectionSegments = @($sectionPath -split '[\\/]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($sectionSegments.Count -eq 0) {
    throw "Section path must not be empty."
  }

  $sectionDir = Join-Path $docsRoot ([System.IO.Path]::Combine($sectionSegments))
  Assert-PathInsideRoot -RootPath $docsRoot -TargetPath $sectionDir

  if (-not (Test-Path -LiteralPath $sectionDir)) {
    throw "Section directory does not exist: $sectionDir"
  }

  $fileStem = ConvertTo-FileStem $pageName
  $pagePath = Join-Path $sectionDir "$fileStem.md"
  $position = if ($parsed.Values.ContainsKey("position")) { [int]$parsed.Values["position"] } else { Get-NextPagePosition -SectionDir $sectionDir }
  $docSlug = Get-SlugForPage -SectionPath $sectionPath -PageName $pageName
  $bridgeStatus = Get-BridgeStatus
  $includeToc = (-not $noToc) -and $bridgeStatus.TocReady

  if ((Test-Path -LiteralPath $pagePath) -and (-not $force)) {
    throw "Page already exists: $pagePath"
  }

  $pageContent = Build-PageContent -Title $title -Slug $docSlug -Position $position -IncludeToc:$includeToc
  Write-Utf8NoBomFile -Path $pagePath -Content $pageContent

  if ($includeToc) {
    $null = Queue-TocRequest -ResolvedRepoRoot $ResolvedRepoRoot -FilePath $pagePath
    [void](Open-PathInVSCode -ResolvedRepoRoot $ResolvedRepoRoot -FilePath $pagePath)
  }

  [pscustomobject]@{
    Command = "new-page"
    Path = $pagePath
    TocQueued = $includeToc
    BridgeStatus = $bridgeStatus
  }
}

function Get-MarkdownDocFiles {
  param([Parameter(Mandatory)][string]$DocsRoot)

  $files = Get-ChildItem -LiteralPath $DocsRoot -Recurse -File -Filter *.md
  return @($files | Where-Object {
      $fullName = $_.FullName
      $fullName -notmatch '\\CodingStandards\\Snapshots\\' -and
      $fullName -notmatch '\\CodingStandards\\Templates\\'
    })
}

function Get-FrontMatterBlock {
  param([Parameter(Mandatory)][string]$Content)

  if ($Content -notmatch '(?s)\A---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|$)') {
    return $null
  }

  return $Matches[1]
}

function Get-FrontMatterValue {
  param(
    [AllowNull()][string]$FrontMatter,
    [Parameter(Mandatory)][string]$Key
  )

  if ([string]::IsNullOrWhiteSpace($FrontMatter)) {
    return $null
  }

  $pattern = "(?m)^\s*$([regex]::Escape($Key))\s*:\s*(.+?)\s*$"
  if ($FrontMatter -notmatch $pattern) {
    return $null
  }

  $value = $Matches[1].Trim()
  if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
    $value = $value.Substring(1, $value.Length - 2)
  }

  return $value
}

function Get-SidebarPositionForMarkdownFile {
  param([Parameter(Mandatory)][string]$FilePath)

  if (-not (Test-Path -LiteralPath $FilePath)) {
    return $null
  }

  $content = Get-Content -LiteralPath $FilePath -Raw
  $frontMatter = Get-FrontMatterBlock -Content $content
  $value = Get-FrontMatterValue -FrontMatter $frontMatter -Key "sidebar_position"
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $null
  }

  $parsed = 0
  if ([int]::TryParse($value, [ref]$parsed)) {
    return $parsed
  }

  return $null
}

function Get-CategoryPositionForDirectory {
  param([Parameter(Mandatory)][string]$DirectoryPath)

  $categoryPath = Join-Path $DirectoryPath "_category_.json"
  if (-not (Test-Path -LiteralPath $categoryPath)) {
    return $null
  }

  $categoryJson = Get-Content -LiteralPath $categoryPath -Raw | ConvertFrom-Json
  if ($null -eq $categoryJson.position) {
    return $null
  }

  $parsed = 0
  if ([int]::TryParse("$($categoryJson.position)", [ref]$parsed)) {
    return $parsed
  }

  return $null
}

function Get-NextSectionPosition {
  param(
    [Parameter(Mandatory)][string]$DocsRoot,
    [Parameter(Mandatory)][string]$SectionPath
  )

  $sectionSegments = @($SectionPath -split '[\\/]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($sectionSegments.Count -le 1) {
    $parentDir = $DocsRoot
  }
  else {
    $parentSegments = @($sectionSegments[0..($sectionSegments.Count - 2)])
    $parentDir = Join-Path $DocsRoot ([System.IO.Path]::Combine($parentSegments))
  }

  $positions = New-Object System.Collections.Generic.List[int]

  foreach ($markdownFile in @(Get-ChildItem -LiteralPath $parentDir -File -Filter *.md -ErrorAction SilentlyContinue)) {
    $position = Get-SidebarPositionForMarkdownFile -FilePath $markdownFile.FullName
    if ($null -ne $position) {
      $positions.Add($position) | Out-Null
    }
  }

  foreach ($childDir in @(Get-ChildItem -LiteralPath $parentDir -Directory -ErrorAction SilentlyContinue)) {
    $position = Get-CategoryPositionForDirectory -DirectoryPath $childDir.FullName
    if ($null -ne $position) {
      $positions.Add($position) | Out-Null
    }
  }

  if ($positions.Count -eq 0) {
    return 1
  }

  return ((($positions.ToArray() | Measure-Object -Maximum).Maximum) + 1)
}

function Get-NextPagePosition {
  param([Parameter(Mandatory)][string]$SectionDir)

  $positions = New-Object System.Collections.Generic.List[int]

  foreach ($markdownFile in @(Get-ChildItem -LiteralPath $SectionDir -File -Filter *.md -ErrorAction SilentlyContinue)) {
    $position = Get-SidebarPositionForMarkdownFile -FilePath $markdownFile.FullName
    if ($null -ne $position) {
      $positions.Add($position) | Out-Null
    }
  }

  if ($positions.Count -eq 0) {
    return 1
  }

  return ((($positions.ToArray() | Measure-Object -Maximum).Maximum) + 1)
}

function Invoke-DocsCheck {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  $docsRoot = Get-DocsRoot -ResolvedRepoRoot $ResolvedRepoRoot
  $websiteRoot = Get-WebsiteRoot -ResolvedRepoRoot $ResolvedRepoRoot
  $docFiles = @(Get-MarkdownDocFiles -DocsRoot $docsRoot)
  $slugToFiles = @{}
  $issues = New-Object System.Collections.Generic.List[string]

  foreach ($file in $docFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $frontMatter = Get-FrontMatterBlock -Content $content
    $slug = Get-FrontMatterValue -FrontMatter $frontMatter -Key "slug"

    if (-not [string]::IsNullOrWhiteSpace($slug)) {
      if ($slug.StartsWith("/docs/", [System.StringComparison]::OrdinalIgnoreCase)) {
        $issues.Add("Slug should not start with /docs/: $($file.FullName) -> $slug") | Out-Null
      }

      if (-not $slugToFiles.ContainsKey($slug)) {
        $slugToFiles[$slug] = New-Object System.Collections.Generic.List[string]
      }

      $slugToFiles[$slug].Add($file.FullName) | Out-Null
    }

    if ($content.Contains($script:TocMarker)) {
      $issues.Add("Unprocessed TOC marker remains in: $($file.FullName)") | Out-Null
    }
  }

  foreach ($entry in $slugToFiles.GetEnumerator()) {
    if ($entry.Value.Count -gt 1) {
      $issues.Add("Duplicate slug '$($entry.Key)' used by: $($entry.Value -join ', ')") | Out-Null
    }
  }

  if (-not (Test-Path -LiteralPath $websiteRoot)) {
    throw "website/ directory not found: $websiteRoot"
  }

  if ($issues.Count -gt 0) {
    $message = @("Docs validation failed:") + @($issues | ForEach-Object { " - $_" })
    throw ($message -join [Environment]::NewLine)
  }

  Push-Location $websiteRoot
  try {
    & npm run build
    if ($LASTEXITCODE -ne 0) {
      throw "npm run build failed (exit $LASTEXITCODE)."
    }
  }
  finally {
    Pop-Location
  }

  return [pscustomobject]@{
    Command = "check"
    FilesChecked = $docFiles.Count
  }
}

function Invoke-WebsiteNpmScript {
  param(
    [Parameter(Mandatory)][string]$ResolvedRepoRoot,
    [Parameter(Mandatory)][string]$ScriptName,
    [string[]]$ScriptArgs = @()
  )

  $websiteRoot = Get-WebsiteRoot -ResolvedRepoRoot $ResolvedRepoRoot
  Push-Location $websiteRoot
  try {
    $npmArgs = @("run", $ScriptName)
    if (@($ScriptArgs).Count -gt 0) {
      $npmArgs += "--"
      $npmArgs += @($ScriptArgs)
    }

    & npm @npmArgs
    if ($LASTEXITCODE -ne 0) {
      throw "npm run $ScriptName failed (exit $LASTEXITCODE)."
    }
  }
  finally {
    Pop-Location
  }
}

function Get-DocsStartUrl {
  param([string[]]$StartArgs = @())

  $port = 3000
  for ($i = 0; $i -lt $StartArgs.Count; $i++) {
    $token = [string]$StartArgs[$i]
    if ($token -eq "--port" -or $token -eq "-p") {
      if (($i + 1) -lt $StartArgs.Count) {
        $parsedPort = 0
        if ([int]::TryParse([string]$StartArgs[$i + 1], [ref]$parsedPort)) {
          $port = $parsedPort
        }
      }
      break
    }
  }

  return "http://localhost:$port/docs/"
}

function Invoke-DocsStart {
  param(
    [Parameter(Mandatory)][string]$ResolvedRepoRoot,
    [string[]]$StartArgs = @()
  )

  $existingState = Get-DocsServerState -ResolvedRepoRoot $ResolvedRepoRoot
  if ($existingState) {
    if (Test-ProcessRunning -ProcessId ([int]$existingState.ProcessId)) {
      return [pscustomobject]@{
        Command = "start"
        AlreadyRunning = $true
        ProcessId = [int]$existingState.ProcessId
        LogPath = [string]$existingState.LogPath
        ErrorLogPath = [string]$existingState.ErrorLogPath
        Url = [string]$existingState.Url
      }
    }

    Remove-DocsServerState -ResolvedRepoRoot $ResolvedRepoRoot
  }

  $runtimeDir = Get-DocsToolsRuntimeDirectory -ResolvedRepoRoot $ResolvedRepoRoot
  $websiteRoot = Get-WebsiteRoot -ResolvedRepoRoot $ResolvedRepoRoot
  New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $stdoutPath = Join-Path $runtimeDir "docs-start-$stamp.stdout.log"
  $stderrPath = Join-Path $runtimeDir "docs-start-$stamp.stderr.log"

  $npmCommandParts = @("npm", "run", "start")
  if (@($StartArgs).Count -gt 0) {
    $npmCommandParts += "--"
    $npmCommandParts += @($StartArgs)
  }

  $commandLine = (@($npmCommandParts) | ForEach-Object { ConvertTo-CmdArgument "$_" }) -join ' '
  $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
  $process = Start-Process `
    -FilePath $pwshPath `
    -ArgumentList @("-NoLogo", "-NoProfile", "-Command", $commandLine) `
    -WorkingDirectory $websiteRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -PassThru

  Start-Sleep -Seconds 2
  $trackedProcessId = if (Test-ProcessRunning -ProcessId $process.Id) { $process.Id } else { Get-DescendantProcessId -RootProcessId $process.Id }
  if ($null -eq $trackedProcessId) {
    $errorText = ""
    if (Test-Path -LiteralPath $stderrPath) {
      $errorText = (Get-Content -LiteralPath $stderrPath -Raw).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($errorText) -and (Test-Path -LiteralPath $stdoutPath)) {
      $errorText = (Get-Content -LiteralPath $stdoutPath -Raw).Trim()
    }

    $details = if ([string]::IsNullOrWhiteSpace($errorText)) { "Check $stdoutPath and $stderrPath." } else { $errorText }
    throw "Docs dev server exited immediately. $details"
  }

  $url = Get-DocsStartUrl -StartArgs $StartArgs
  $state = [ordered]@{
    version = 1
    rootProcessId = $process.Id
    processId = $trackedProcessId
    startedAt = (Get-Date).ToString("o")
    websiteRoot = $websiteRoot
    logPath = $stdoutPath
    errorLogPath = $stderrPath
    url = $url
    args = @($StartArgs)
  }

  $statePath = Save-DocsServerState -ResolvedRepoRoot $ResolvedRepoRoot -State $state

  return [pscustomobject]@{
    Command = "start"
    AlreadyRunning = $false
    ProcessId = $trackedProcessId
    RootProcessId = $process.Id
    LogPath = $stdoutPath
    ErrorLogPath = $stderrPath
    StatePath = $statePath
    Url = $url
  }
}

function Invoke-DocsStop {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  $state = Get-DocsServerState -ResolvedRepoRoot $ResolvedRepoRoot
  if (-not $state) {
    return [pscustomobject]@{
      Command = "stop"
      Status = "not_running"
    }
  }

  $processId = [int]$state.processId
  $rootProcessId = if ($null -ne $state.rootProcessId) { [int]$state.rootProcessId } else { $processId }
  if (-not (Test-ProcessRunning -ProcessId $processId) -and -not (Test-ProcessRunning -ProcessId $rootProcessId)) {
    Remove-DocsServerState -ResolvedRepoRoot $ResolvedRepoRoot
    return [pscustomobject]@{
      Command = "stop"
      Status = "stale_state_removed"
      ProcessId = $processId
    }
  }

  $targetPid = if (Test-ProcessRunning -ProcessId $rootProcessId) { $rootProcessId } else { $processId }
  $taskKillPath = Join-Path $env:SystemRoot "System32\taskkill.exe"
  if (Test-Path -LiteralPath $taskKillPath) {
    & $taskKillPath /PID $targetPid /T /F | Out-Null
  }
  else {
    Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
  }

  Start-Sleep -Milliseconds 750
  if (Test-ProcessRunning -ProcessId $processId) {
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
  }
  if (Test-ProcessRunning -ProcessId $rootProcessId) {
    Stop-Process -Id $rootProcessId -Force -ErrorAction SilentlyContinue
  }

  Remove-DocsServerState -ResolvedRepoRoot $ResolvedRepoRoot
  return [pscustomobject]@{
    Command = "stop"
    Status = "stopped"
    ProcessId = $processId
  }
}

function Invoke-InstallBridge {
  param([Parameter(Mandatory)][string]$ResolvedRepoRoot)

  $bridgeSource = Join-Path $PSScriptRoot "VSCodeBridge"
  $packagePath = Join-Path $bridgeSource "package.json"
  if (-not (Test-Path -LiteralPath $packagePath)) {
    throw "VS Code bridge package.json not found: $packagePath"
  }

  $packageJson = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
  $publisher = [string]$packageJson.publisher
  $name = [string]$packageJson.name
  $version = [string]$packageJson.version
  if ([string]::IsNullOrWhiteSpace($publisher) -or [string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($version)) {
    throw "Bridge package.json is missing publisher, name, or version."
  }

  $extensionsRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
  New-Item -ItemType Directory -Force -Path $extensionsRoot | Out-Null

  $prefix = "$publisher.$name-"
  Get-ChildItem -LiteralPath $extensionsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "$prefix*" } |
    ForEach-Object {
      $resolved = $_.FullName
      if ($resolved.StartsWith($extensionsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
      }
    }

  $destination = Join-Path $extensionsRoot "$publisher.$name-$version"
  Copy-Item -LiteralPath $bridgeSource -Destination $destination -Recurse -Force

  return [pscustomobject]@{
    Command = "install-bridge"
    Destination = $destination
    MarkdownAllInOneInstalled = (Test-VSCodeExtensionInstalled -ExtensionId $script:MarkdownAllInOneExtensionId)
  }
}

function Invoke-DocsToolsMain {
  param(
    [Parameter(Mandatory)][string]$ResolvedRepoRoot,
    [string[]]$Args
  )

  $allArgs = @($Args)
  $helpTokens = @("help", "--help", "-help", "-h", "/?", "-?")
  if ($allArgs.Count -eq 0 -or ($helpTokens -contains ([string]$allArgs[0]).ToLowerInvariant())) {
    Write-Output (Get-DocsToolsHelp)
    return
  }

  $command = ([string]$allArgs[0]).ToLowerInvariant()
  $remaining = if ($allArgs.Count -gt 1) { @($allArgs[1..($allArgs.Count - 1)]) } else { @() }

  switch ($command) {
    "new-section" {
      $result = Invoke-NewSection -ResolvedRepoRoot $ResolvedRepoRoot -Args $remaining
      Write-Output "Created section: $($result.Path)"
      Write-Output "Category metadata: $($result.CategoryPath)"
      if ($result.TocQueued) { Write-Output "TOC request queued through the VS Code bridge." }
      else { Write-Output "TOC generation skipped." }
      return
    }
    "new-page" {
      $result = Invoke-NewPage -ResolvedRepoRoot $ResolvedRepoRoot -Args $remaining
      Write-Output "Created page: $($result.Path)"
      if ($result.TocQueued) { Write-Output "TOC request queued through the VS Code bridge." }
      else { Write-Output "TOC generation skipped." }
      return
    }
    "preview" {
      Write-Output "preview is deprecated. Use 'docs-tools start'."
      $result = Invoke-DocsStart -ResolvedRepoRoot $ResolvedRepoRoot -StartArgs $remaining
      if ($result.AlreadyRunning) {
        Write-Output "Docs dev server is already running (PID $($result.ProcessId))."
      }
      else {
        Write-Output "Started docs dev server in the background (PID $($result.ProcessId))."
      }
      Write-Output "URL: $($result.Url)"
      Write-Output "Stdout log: $($result.LogPath)"
      Write-Output "Stderr log: $($result.ErrorLogPath)"
      return
    }
    "start" {
      $result = Invoke-DocsStart -ResolvedRepoRoot $ResolvedRepoRoot -StartArgs $remaining
      if ($result.AlreadyRunning) {
        Write-Output "Docs dev server is already running (PID $($result.ProcessId))."
      }
      else {
        Write-Output "Started docs dev server in the background (PID $($result.ProcessId))."
      }
      Write-Output "URL: $($result.Url)"
      Write-Output "Stdout log: $($result.LogPath)"
      Write-Output "Stderr log: $($result.ErrorLogPath)"
      return
    }
    "stop" {
      $result = Invoke-DocsStop -ResolvedRepoRoot $ResolvedRepoRoot
      switch ($result.Status) {
        "not_running" { Write-Output "Docs dev server is not running." }
        "stale_state_removed" { Write-Output "Removed stale docs dev server state for PID $($result.ProcessId)." }
        default { Write-Output "Stopped docs dev server (PID $($result.ProcessId))." }
      }
      return
    }
    "check" {
      $result = Invoke-DocsCheck -ResolvedRepoRoot $ResolvedRepoRoot
      Write-Output "Docs check passed. Files checked: $($result.FilesChecked)"
      return
    }
    "install-bridge" {
      $result = Invoke-InstallBridge -ResolvedRepoRoot $ResolvedRepoRoot
      Write-Output "Installed VS Code bridge to: $($result.Destination)"
      if ($result.MarkdownAllInOneInstalled) {
        Write-Output "Markdown All in One is already installed."
      }
      else {
        Write-Output "Markdown All in One is not installed. TOC generation will still be skipped until it is present."
      }
      Write-Output "Reload VS Code windows to activate the bridge."
      return
    }
    default {
      $packageScripts = @(Get-WebsitePackageScriptNames -ResolvedRepoRoot $ResolvedRepoRoot)
      if ($packageScripts -contains $command) {
        Invoke-WebsiteNpmScript -ResolvedRepoRoot $ResolvedRepoRoot -ScriptName $command -ScriptArgs $remaining
        return
      }

      throw "Unknown docs-tools command '$command'. Run 'docs-tools help'."
    }
  }
}

$resolvedRepoRoot = Get-DocsToolsRepoRoot -ExplicitRepoRoot $RepoRoot
Invoke-DocsToolsMain -ResolvedRepoRoot $resolvedRepoRoot -Args $CommandArgs
