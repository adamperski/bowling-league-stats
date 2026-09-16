<#
    Reusable importer: writes a full week's hand-transcribed lineups (from a
    printed full-week report PDF, or the live currentscores?id= report while
    it's still up) into data\lineups\<date>.json as resolved:true entries -
    the strict pairingConfirmed rule in Build-Stats.ps1 only trusts an entry
    written this way.

    Each week, transcribe the report into its own small data file under
    scripts\lineup-sources\<date>.ps1 (see 2026-09-08.ps1 for the format and
    an existing worked example) using the T() helper defined below, then run:

        .\scripts\Import-WeekReport.ps1 -Date 2026-09-08 `
            -DataFile scripts\lineup-sources\2026-09-08.ps1 `
            -Source "Full week report PDF, printed 2026-09-15"

    Extraction tips (see README / memory for more detail):
    - `pdftotext -layout report.pdf report.txt` is usually readable directly.
    - If a block's columns look misaligned (numbers don't line up with
      names), re-extract WITHOUT -layout for just that page
      (`pdftotext -f N -l N report.pdf page.txt`) and use the raw
      column-major token order instead.
    - Cross-check: for a bowler at average `avg`, their printed handicap
      total should equal scratchTotal + 3*floor((235-avg)*0.9). Use this to
      confirm which raw numbers belong to which name when a block is
      ambiguous, before transcribing.
#>
param(
    [Parameter(Mandatory)] [string]$Date,
    [Parameter(Mandatory)] [string]$DataFile,
    [string]$Source = "Full week report, imported $(Get-Date -Format 'yyyy-MM-dd')"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$file = Join-Path $root "data\lineups\$Date.json"
if (-not (Test-Path $DataFile)) { throw "Data file not found: $DataFile" }

function T($name, $avg, $kind = 'bowler', $subFor = $null, $blindFor = $null) {
    [ordered]@{ name = $name; kind = $kind; avg = $avg; subFor = $subFor; blindFor = $blindFor }
}

# Dot-sourced in this scope so it can see T() above and set $teams here.
. $DataFile
if (-not $teams -or $teams.Count -eq 0) { throw "$DataFile did not populate `$teams" }

# ---- sanity checks (catch typos before they land in the lineup file) ----
$snapshotRoot = Join-Path $root 'data\raw'
$latestSnap = if (Test-Path $snapshotRoot) { Get-ChildItem $snapshotRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1 } else { $null }
$knownTeams = $null
if ($latestSnap) {
    $standingsPath = Join-Path $latestSnap.FullName 'standings.json'
    if (Test-Path $standingsPath) {
        $standings = (Get-Content -Raw $standingsPath | ConvertFrom-Json).data
        $knownTeams = @($standings.standings | Where-Object { -not $_.team.isBye -and -not $_.team.isPacer } | ForEach-Object { $_.team.name })
    }
}
$warnings = @()
foreach ($tname in $teams.Keys) {
    $roster = @($teams[$tname])
    if ($roster.Count -ne 5) { $warnings += "'$tname' has $($roster.Count) lineup entries (expected 5)" }
    $dupes = @($roster | ForEach-Object { $_.name } | Group-Object | Where-Object Count -gt 1)
    foreach ($d in $dupes) { $warnings += "'$tname' lists '$($d.Name)' more than once" }
    if ($knownTeams -and $knownTeams -notcontains $tname) { $warnings += "'$tname' doesn't match any team name in the latest snapshot ($($latestSnap.Name)) - typo?" }
}
if ($knownTeams) {
    $missingTeams = @($knownTeams | Where-Object { $teams.Keys -notcontains $_ })
    if ($missingTeams.Count -gt 0) { $warnings += "Not covered by this import: $($missingTeams -join ', ')" }
}
if ($warnings.Count -gt 0) {
    Write-Warning 'Review before trusting this import:'
    $warnings | ForEach-Object { Write-Warning "  $_" }
}

# ---- merge into data\lineups\<date>.json ----
$doc = if (Test-Path $file) { Get-Content -Raw $file | ConvertFrom-Json } else {
    [pscustomobject]@{ date = $Date; _help = 'Full week import from a printed/live report.'; teams = [ordered]@{} }
}
if (-not $doc.teams) { $doc | Add-Member -Force teams ([pscustomobject]@{}) }

foreach ($tname in $teams.Keys) {
    $roster = @($teams[$tname])
    $lineup = @()
    for ($i = 0; $i -lt $roster.Count; $i++) {
        $lineup += [ordered]@{
            pos      = $i + 1
            kind     = $roster[$i].kind
            name     = $roster[$i].name
            blindFor = $roster[$i].blindFor
            subFor   = $roster[$i].subFor
            avg      = $roster[$i].avg
        }
    }
    $entry = [ordered]@{
        resolved     = $true
        autoFlags    = @()
        verifiedFrom = $Source
        lineup       = $lineup
    }
    $doc.teams | Add-Member -Force $tname $entry
}

$doc | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 $file
Write-Host "Wrote $($teams.Count) verified team-lineups into $file"
