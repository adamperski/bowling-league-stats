<#
    Records which lane pair each matchup bowled on for one week into
    data\lanes.json (committed; the public API has no lane data, so this is
    transcribed from the printed report's "Lanes 1-2"-style headings).

    Each week, add scripts\lane-sources\<date>.ps1 listing the matchups, one
    per line, using the L() helper (pair, team A, team B):

        $lanes = @(
            L '1-2' 'Chicken Nuggies' 'Denver Vibrator'
            ...
        )

    then run:  .\scripts\Import-Lanes.ps1 -Date 2026-10-06

    Team names are resolved to team IDs from the latest snapshot and the IDs
    are what Build-Stats.ps1 matches on, so a later team rename doesn't break
    old weeks (but the name used HERE must be the current name when you run it).
#>
param([Parameter(Mandatory)] [string]$Date)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "scripts\lane-sources\$Date.ps1"
if (-not (Test-Path $src)) { throw "Lane source not found: $src" }

function L($pair, $a, $b) { [pscustomobject]@{ pair = $pair; a = $a; b = $b } }
. $src
if (-not $lanes -or @($lanes).Count -eq 0) { throw "$src did not populate `$lanes" }

$snap = Get-ChildItem (Join-Path $root 'data\raw') -Directory | Sort-Object Name -Descending | Select-Object -First 1
$standings = (Get-Content -Raw (Join-Path $snap.FullName 'standings.json') | ConvertFrom-Json).data
$idByName = @{}
foreach ($r in $standings.standings) { if ($r.team._id -and -not $r.team.isBye -and -not $r.team.isPacer) { $idByName[$r.team.name] = $r.team._id } }

$problems = @(); $seen = @{}; $out = @()
foreach ($row in @($lanes)) {
    if ($row.pair -notmatch '^\d+-\d+$') { $problems += "bad lane pair '$($row.pair)'" }
    foreach ($n in $row.a, $row.b) {
        if (-not $idByName.ContainsKey($n)) { $problems += "'$n' is not a current team name in snapshot $($snap.Name) (renamed?)"; continue }
        if ($seen.ContainsKey($n)) { $problems += "'$n' listed more than once" }
        $seen[$n] = $true
    }
    $out += [ordered]@{ pair = $row.pair; a = $row.a; aId = $idByName[$row.a]; b = $row.b; bId = $idByName[$row.b] }
}
$missing = @($idByName.Keys | Where-Object { -not $seen.ContainsKey($_) })
if ($missing.Count) { $problems += "teams with no lane this week: $($missing -join ', ')" }
$pairs = @($lanes | ForEach-Object { $_.pair })
if (($pairs | Sort-Object -Unique).Count -ne $pairs.Count) { $problems += 'a lane pair is used twice' }
if ($problems.Count) { $problems | ForEach-Object { Write-Warning $_ }; throw "Lane data for $Date has problems - fix $src and re-run." }

$file = Join-Path $root 'data\lanes.json'
$doc = if (Test-Path $file) { Get-Content -Raw $file | ConvertFrom-Json } else { [pscustomobject]@{ _help = 'Lane pair per matchup per week; see scripts\Import-Lanes.ps1. Keyed by date.'; weeks = [pscustomobject]@{} } }
$doc.weeks | Add-Member -Force $Date @($out)
$doc | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 $file
Write-Host "Wrote $(@($out).Count) lane pairings for $Date into $file"
