[CmdletBinding()]
param(
  [string]$SnapshotPath,
  [string]$OutputPath
)

$ErrorActionPreference = "Stop"

function Normalize-Whitespace {
  param([string]$Text)

  $out = $Text -replace "`r", ""
  $out = $out -replace "[ \t]+`n", "`n"
  $out = $out -replace "`n{3,}", "`n`n"
  return $out.Trim() + "`n"
}

function Decode-Html {
  param([string]$Text)
  return [System.Net.WebUtility]::HtmlDecode($Text)
}

function Convert-InlineHtmlToMarkdown {
  param([string]$HtmlFragment)

  $text = $HtmlFragment

  # Links first to preserve target URLs.
  $text = [regex]::Replace(
    $text,
    '(?is)<a\b[^>]*href="(?<href>[^"]+)"[^>]*>(?<txt>.*?)</a>',
    {
      param($m)
      $href = $m.Groups['href'].Value
      if ($href.StartsWith("/")) {
        $href = "https://dev.epicgames.com$href"
      }

      $txt = $m.Groups['txt'].Value
      $txt = [regex]::Replace($txt, '(?is)<[^>]+>', '')
      $txt = Decode-Html $txt
      $txt = $txt.Trim()
      if ([string]::IsNullOrWhiteSpace($txt)) { $txt = $href }
      return "[$txt]($href)"
    }
  )

  # Inline code / emphasis / strong.
  $text = [regex]::Replace($text, '(?is)<code\b[^>]*>(?<c>.*?)</code>', { param($m) '`' + (Decode-Html $m.Groups['c'].Value).Trim() + '`' })
  $text = [regex]::Replace($text, '(?is)<strong\b[^>]*>(?<s>.*?)</strong>', { param($m) '**' + (Decode-Html ([regex]::Replace($m.Groups['s'].Value,'(?is)<[^>]+>',''))).Trim() + '**' })
  $text = [regex]::Replace($text, '(?is)<em\b[^>]*>(?<e>.*?)</em>', { param($m) '*' + (Decode-Html ([regex]::Replace($m.Groups['e'].Value,'(?is)<[^>]+>',''))).Trim() + '*' })
  $text = [regex]::Replace($text, '(?is)<br\s*/?>', "`n")

  # Strip any remaining tags.
  $text = [regex]::Replace($text, '(?is)<[^>]+>', '')
  $text = Decode-Html $text
  $text = $text -replace "\u00A0", " "
  $text = [regex]::Replace($text, '[ \t]+', ' ')
  $text = [regex]::Replace($text, " *`n *", "`n")
  return $text.Trim()
}

function Convert-TableHtmlToMarkdown {
  param([string]$TableHtml)

  $rows = [regex]::Matches($TableHtml, '(?is)<tr\b[^>]*>(?<row>.*?)</tr>')
  if ($rows.Count -eq 0) { return "" }

  $tableRows = @()
  foreach ($r in $rows) {
    $cells = [regex]::Matches($r.Groups['row'].Value, '(?is)<t[hd]\b[^>]*>(?<cell>.*?)</t[hd]>')
    if ($cells.Count -eq 0) { continue }
    $row = @()
    foreach ($c in $cells) {
      $row += (Convert-InlineHtmlToMarkdown $c.Groups['cell'].Value)
    }
    $tableRows += ,$row
  }

  if ($tableRows.Count -eq 0) { return "" }

  $maxCols = ($tableRows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
  for ($i = 0; $i -lt $tableRows.Count; $i++) {
    while ($tableRows[$i].Count -lt $maxCols) {
      $tableRows[$i] += ""
    }
  }

  $header = $tableRows[0]
  $separator = @()
  for ($i = 0; $i -lt $maxCols; $i++) { $separator += "---" }

  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("| " + ($header -join " | ") + " |")
  [void]$sb.AppendLine("| " + ($separator -join " | ") + " |")

  for ($i = 1; $i -lt $tableRows.Count; $i++) {
    [void]$sb.AppendLine("| " + ($tableRows[$i] -join " | ") + " |")
  }

  return $sb.ToString().TrimEnd()
}

function Convert-ContentHtmlToMarkdown {
  param([string]$ContentHtml)

  $text = $ContentHtml

  # Remove copy buttons from code blocks.
  $text = [regex]::Replace($text, '(?is)<button\b[^>]*>.*?</button>', '')

  # Extract <pre><code> blocks and replace with placeholders.
  $codeMap = @{}
  $text = [regex]::Replace(
    $text,
    '(?is)<pre\b[^>]*>\s*<code\b[^>]*>(?<code>.*?)</code>\s*</pre>',
    {
      param($m)
      $id = "@@CODEBLOCK_$([Guid]::NewGuid().ToString('N'))@@"

      $code = Decode-Html $m.Groups['code'].Value
      $code = $code -replace "`r", ""
      $code = $code.TrimEnd()
      $codeMap[$id] = '```cpp' + "`n" + $code + "`n" + '```'
      return "`n`n$id`n`n"
    }
  )

  # Extract tables and replace with placeholders.
  $tableMap = @{}
  $text = [regex]::Replace(
    $text,
    '(?is)<table\b[^>]*>.*?</table>',
    {
      param($m)
      $id = "@@TABLE_$([Guid]::NewGuid().ToString('N'))@@"
      $tableMap[$id] = Convert-TableHtmlToMarkdown $m.Value
      return "`n`n$id`n`n"
    }
  )

  # Headings.
  $text = [regex]::Replace($text, '(?is)<h2\b[^>]*>(?<h>.*?)</h2>', { param($m) "`n`n## " + (Convert-InlineHtmlToMarkdown $m.Groups['h'].Value) + "`n`n" })
  $text = [regex]::Replace($text, '(?is)<h3\b[^>]*>(?<h>.*?)</h3>', { param($m) "`n`n### " + (Convert-InlineHtmlToMarkdown $m.Groups['h'].Value) + "`n`n" })
  $text = [regex]::Replace($text, '(?is)<h4\b[^>]*>(?<h>.*?)</h4>', { param($m) "`n`n#### " + (Convert-InlineHtmlToMarkdown $m.Groups['h'].Value) + "`n`n" })

  # Lists.
  $text = [regex]::Replace($text, '(?is)<ul\b[^>]*>', "`n")
  $text = [regex]::Replace($text, '(?is)</ul>', "`n")
  $text = [regex]::Replace($text, '(?is)<li\b[^>]*>', "`n- ")
  $text = [regex]::Replace($text, '(?is)</li>', "")

  # Paragraphs / line breaks.
  $text = [regex]::Replace($text, '(?is)<p\b[^>]*>', '')
  $text = [regex]::Replace($text, '(?is)</p>', "`n`n")
  $text = [regex]::Replace($text, '(?is)<br\s*/?>', "`n")

  # Inline conversion for remaining content.
  $text = Convert-InlineHtmlToMarkdown $text

  # Re-expand placeholders with exact token matches to avoid key collision issues.
  $text = [regex]::Replace(
    $text,
    '@@TABLE_[0-9a-fA-F]{32}@@',
    {
      param($m)
      if ($tableMap.ContainsKey($m.Value)) { return $tableMap[$m.Value] }
      return $m.Value
    }
  )

  $text = [regex]::Replace(
    $text,
    '@@CODEBLOCK_[0-9a-fA-F]{32}@@',
    {
      param($m)
      if ($codeMap.ContainsKey($m.Value)) { return $codeMap[$m.Value] }
      return $m.Value
    }
  )

  # Ensure headings and fenced blocks have clean spacing.
  $text = [regex]::Replace($text, '(?m)^(##+ .+)$', "`n`$1")
  $text = [regex]::Replace($text, '(?m)^-\s*\n\s*', '- ')
  $text = Normalize-Whitespace $text
  return $text
}

$repoRoot = (git rev-parse --show-toplevel 2>$null).Trim()
if (-not $repoRoot) { throw "Not inside a git repository." }

$codingRoot = Join-Path $repoRoot "Docs/CodingStandards"
$snapshotsRoot = Join-Path $codingRoot "Snapshots"

if (-not $SnapshotPath) {
  $latest = Get-ChildItem $snapshotsRoot -Directory |
    Where-Object { $_.Name -ne ".gitkeep" } |
    Sort-Object Name -Descending |
    Select-Object -First 1
  if (-not $latest) { throw "No snapshot folders found under $snapshotsRoot." }
  $SnapshotPath = $latest.FullName
}

if (-not (Test-Path $SnapshotPath)) { throw "Snapshot path not found: $SnapshotPath" }

$pagePath = Join-Path $SnapshotPath "page.html"
if (-not (Test-Path $pagePath)) { throw "Snapshot page.html not found: $pagePath" }

$generatedRoot = Join-Path $codingRoot "Generated"
New-Item -ItemType Directory -Path $generatedRoot -Force | Out-Null

if (-not $OutputPath) {
  $OutputPath = Join-Path $generatedRoot "UnrealCppStandard-Digest.md"
}

$rawPage = Get-Content $pagePath -Raw
$contentMatch = [regex]::Match($rawPage, '(?s)"content_html":"(?<content>.*?)","settings"\s*:\s*\{')
if (-not $contentMatch.Success) {
  throw "Could not locate content_html payload in snapshot page."
}

$encoded = $contentMatch.Groups["content"].Value
$contentHtml = ConvertFrom-Json ('"' + $encoded + '"')
$bodyMd = Convert-ContentHtmlToMarkdown $contentHtml

$snapshotName = Split-Path $SnapshotPath -Leaf
$relativePagePath = [System.IO.Path]::GetRelativePath($repoRoot, $pagePath)
$sourceMdPath = Join-Path $SnapshotPath "SOURCE.md"
$sourceSummary = if (Test-Path $sourceMdPath) { (Get-Content $sourceMdPath -Raw).Trim() } else { "_SOURCE.md not found in snapshot._" }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Unreal C++ Coding Standard (Parsed Snapshot)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Snapshot")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- Snapshot folder: $snapshotName")
[void]$sb.AppendLine("- Snapshot page: $relativePagePath")
[void]$sb.AppendLine("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Source Metadata")
[void]$sb.AppendLine("")
[void]$sb.AppendLine($sourceSummary)
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Parsed Content")
[void]$sb.AppendLine("")
[void]$sb.AppendLine($bodyMd)

Set-Content -Path $OutputPath -Value $sb.ToString() -Encoding UTF8

$h2Count = ([regex]::Matches($contentHtml, '(?is)<h2\b')).Count
$h3Count = ([regex]::Matches($contentHtml, '(?is)<h3\b')).Count
$preCount = ([regex]::Matches($contentHtml, '(?is)<pre\b')).Count

Write-Host "[CodingStandards] Parsed snapshot -> markdown:"
Write-Host "  $OutputPath"
Write-Host "[CodingStandards] Source blocks: h2=$h2Count h3=$h3Count pre=$preCount"
