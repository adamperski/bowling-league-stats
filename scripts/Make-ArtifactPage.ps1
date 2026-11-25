<#
    Make-ArtifactPage.ps1

    Turns the built dashboard (docs\index.html) into the page file for a published Claude Artifact:
    the Artifact tool wraps the file in its own <!doctype>/<html>/<head>/<body> skeleton, so the
    document tags are stripped and the title + viewport-fit marker go on top. Inside the artifact the
    "Ask Claude" tab uses the viewer's own Claude account (the `sample` capability) instead of an API key.

        .\Build-Stats.ps1
        .\scripts\Make-ArtifactPage.ps1      # -> data\out\artifact\league-stats.html

    Publish that file as an Artifact with capabilities {sample: {}} (ask Claude Code to "republish the
    artifact"); it does not update itself, so republish after a weekly update when you want fresh data.
#>
[CmdletBinding()]
param([string]$Title = 'Pioneer I League Stats')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'docs\index.html'
if (-not (Test-Path $src)) { throw "Run .\Build-Stats.ps1 first ($src is missing)." }

$html = [IO.File]::ReadAllText($src, [Text.Encoding]::UTF8)
$head = "<title>$Title</title>`n<meta name=`"claude:viewport-fit-sides`" content=`"cover`">`n<style>"
$n0 = $html.Length
$html = [regex]::Replace($html, '(?s)\A.*?<title>.*?</title>\s*<style>', { param($m) $head }, 1)   # doctype/html/head/meta/title -> artifact header
$html = [regex]::Replace($html, '(?s)</style>\s*</head>\s*<body>', '</style>', 1)
$html = [regex]::Replace($html, '(?s)\s*</body>\s*</html>\s*\z', "`n", 1)
if ($html -match '(?i)<!doctype|<html[\s>]|<head[\s>]|<body[\s>]') { throw 'Some document tags are still in the page - the template layout changed.' }

$outDir = Join-Path $root 'data\out\artifact'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out = Join-Path $outDir 'league-stats.html'
[IO.File]::WriteAllText($out, $html, [Text.UTF8Encoding]::new($false))
$mb = [math]::Round((Get-Item $out).Length / 1MB, 2)
Write-Host "artifact page -> $out ($mb MB; the Artifact limit is 16 MB)"
if ($mb -gt 15.5) { Write-Warning 'Close to the 16 MB Artifact size limit.' }
