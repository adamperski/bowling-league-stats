<#
    Import-ScoreSheets.ps1

    Turns archived score sheets (data\scoresheets\<slug>\<date>.json, from
    Fetch-ScoreSheets.ps1) into the files the build uses:
      * lineups  -> data\lineups\<date>.json           (current season)
                    data\seasons\<slug>\lineups\<date>.json   (past season)
      * lanes    -> data\lanes.json  /  data\seasons\<slug>\lanes.json

    Every seat comes straight from the score sheet: players are listed in seat
    order, and each game carries its own blind / substitute / vacant flag, the
    average used and the handicap, so nothing has to be guessed or typed in.

    Usage:
        .\scripts\Import-ScoreSheets.ps1 -Compare                  # current season: diff vs the hand-built lineups, write nothing
        .\scripts\Import-ScoreSheets.ps1                           # current season: write lineups + lanes
        .\scripts\Import-ScoreSheets.ps1 -Season 2022-23           # a past season
        .\scripts\Import-ScoreSheets.ps1 -Date 2026-10-13          # one week only
#>
[CmdletBinding()]
param([string]$Season, [string]$Date, [switch]$Compare)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$cfg  = Get-Content -Raw (Join-Path $root 'config.json') | ConvertFrom-Json
if ($Season) {
    $slug = $Season; $snapDir = Join-Path $root "data\seasons\$Season"
    $lineupDir = Join-Path $snapDir 'lineups'; $lanesFile = Join-Path $snapDir 'lanes.json'
} else {
    $slug = $cfg.seasonSlug
    $snapDir = (Get-ChildItem (Join-Path $root 'data\raw') -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
    $lineupDir = Join-Path $root 'data\lineups'; $lanesFile = Join-Path $root 'data\lanes.json'
}
$sheetDir = Join-Path $root "data\scoresheets\$slug"
if (-not (Test-Path $sheetDir)) { throw "No score sheets at $sheetDir - run Fetch-ScoreSheets.ps1 first" }

# every name a bowler can appear under (stored full name AND nickname display), to catch lookup misses
$known = New-Object System.Collections.Generic.HashSet[string]
$knownIds = New-Object System.Collections.Generic.HashSet[string]
Get-ChildItem $snapDir -Filter 'team_*.json' | ForEach-Object {
    foreach ($b in (Get-Content -Raw $_.FullName | ConvertFrom-Json).data) {
        [void]$known.Add("$($b.name)"); [void]$knownIds.Add("$($b._id)")
        if ($b.useNickname -and $b.nickNames -and $b.nickNames[0]) { [void]$known.Add("$($b.nickNames[0])") }
    }
}
$hcRule = ((Get-Content -Raw (Join-Path $snapDir 'league.json') | ConvertFrom-Json).data).handicapRules
function Get-H([double]$a) { $h = [math]::Floor(([int]$hcRule.percentageOf - $a) * ([double]$hcRule.percentage / 100)); if ($h -lt 0 -and -not $hcRule.allowNegative) { $h = 0 }; [int]$h }

$notes = New-Object System.Collections.ArrayList
function Seat-Entry($p, $pos, $ctx) {
    $gs = @($p.games)
    $nB = @($gs | Where-Object { $_.b }).Count; $nV = @($gs | Where-Object { $_.v }).Count
    $subs = @($gs | Where-Object { $_.s -and $_.n })
    if ($p.vacant -or ($gs.Count -and $nV -eq $gs.Count)) {
        # vacancy score: the engine scores a blind at (avg - 10), so feed it pins + 10
        return [ordered]@{ pos = $pos; kind = 'blind'; name = 'Vacant'; blindFor = $null; subFor = $null; avg = [int]$gs[0].p + 10 }
    }
    if ($gs.Count -and $nB -eq $gs.Count) {
        return [ordered]@{ pos = $pos; kind = 'blind'; id = $p.id; name = $p.name; blindFor = $p.name; subFor = $null; avg = [int]$gs[0].a }
    }
    if ($subs.Count) {
        $by = $subs | Group-Object { $_.n } | Sort-Object Count -Descending
        $who = $by[0].Name
        if ($subs.Count -lt $gs.Count -or $by.Count -gt 1) { [void]$notes.Add("$($ctx): seat $pos mixes people ($($p.name) / $(($by.Name) -join ', ')) - kept '$who' (majority)") }
        return [ordered]@{ pos = $pos; kind = 'sub'; name = $who; blindFor = $null; subFor = $p.name; avg = [int]$by[0].Group[0].a }
    }
    $ref = @($gs | Where-Object { -not $_.b })[0]; if (-not $ref) { $ref = $gs[0] }
    [ordered]@{ pos = $pos; kind = 'bowler'; id = $p.id; name = $p.name; blindFor = $null; subFor = $null; avg = [int]$ref.a }
}

$files = Get-ChildItem $sheetDir -Filter '*.json' | Sort-Object Name
if ($Date) { $files = @($files | Where-Object { $_.BaseName -eq $Date }) }
$laneDoc = if ((Test-Path $lanesFile) -and -not $Compare) { Get-Content -Raw $lanesFile | ConvertFrom-Json } else { $null }
if (-not $laneDoc) { $laneDoc = [pscustomobject]@{ _help = 'Lane pair per matchup per week; written by scripts\Import-ScoreSheets.ps1 (or Import-Lanes.ps1). Keyed by date.'; weeks = [pscustomobject]@{} } }
$totalDiff = 0; $unknown = New-Object System.Collections.ArrayList; $hdMismatch = 0

foreach ($f in $files) {
    $doc = Get-Content -Raw $f.FullName | ConvertFrom-Json
    $teamsOut = [ordered]@{}; $laneRows = @()
    foreach ($m in @($doc.matches)) {
        $laneNums = @(@($m.teams) | ForEach-Object { $_.lane } | Where-Object { $_ -ne $null } | ForEach-Object { [int]$_ } | Sort-Object)
        $pair = if ($laneNums.Count -eq 2) { "$($laneNums[0])-$($laneNums[1])" } else { $null }
        $t = @($m.teams)
        if ($pair -and $t.Count -eq 2) {
            $laneRows += [ordered]@{ pair = $pair; a = $t[0].team; aId = $t[0].teamId; b = $t[1].team; bId = $t[1].teamId; aLane = $t[0].lane; bLane = $t[1].lane }
        }
        foreach ($tm in $t) {
            $lineup = @(); $pos = 0
            foreach ($p in @($tm.players)) {
                $pos++
                $e = Seat-Entry $p $pos "$($f.BaseName) $($tm.team)"
                # the seat's real scored games, per-game handicap and per-game flags (B blind, V vacant,
                # I incomplete) - the build scores the matchup from these, no estimating
                $e['games'] = @($p.games | ForEach-Object { [int]$_.p })
                $e['hdcps'] = @($p.games | ForEach-Object { [int]$_.h })
                $e['flags'] = @($p.games | ForEach-Object { "$(if ($_.b) { 'B' })$(if ($_.v) { 'V' })$(if ($_.i) { 'I' })" })
                $lineup += $e
                if ($e.kind -ne 'blind' -or $e.name -ne 'Vacant') {
                    $miss = if ($e.id) { -not $knownIds.Contains("$($e.id)") } else { $e.name -and -not $known.Contains("$($e.name)") }
                    if ($miss) { [void]$unknown.Add("$($f.BaseName) $($tm.team): '$($e.name)' ($($e.kind))") }
                }
                $g0 = @($p.games)[0]
                if ($e.kind -ne 'blind' -and $g0 -and $g0.h -ne $null -and (Get-H $e.avg) -ne [int]$g0.h) { $hdMismatch++ }
            }
            $teamsOut[$tm.team] = [ordered]@{ resolved = $true; autoFlags = @(); verifiedFrom = "score sheet API (recentScoresPublic), $slug"; teamId = $tm.teamId; officialPoints = $tm.points; lineup = $lineup }
        }
    }
    if ($Compare) {
        $old = Join-Path $lineupDir "$($f.BaseName).json"
        if (-not (Test-Path $old)) { Write-Host "$($f.BaseName): no existing lineup file to compare"; continue }
        $od = Get-Content -Raw $old | ConvertFrom-Json
        $dTeams = 0; $lines = @()
        foreach ($k in $teamsOut.Keys) {
            $ol = $od.teams.$k; if (-not $ol) { $lines += "  $k : missing in existing file"; $dTeams++; continue }
            $a = @($teamsOut[$k].lineup | ForEach-Object { "$($_.kind):$($_.name)" }); $b = @($ol.lineup | ForEach-Object { "$($_.kind):$($_.name)" })
            if (($a -join '|') -ne ($b -join '|')) { $dTeams++; $lines += "  $k"; $lines += "     new: $($a -join ' | ')"; $lines += "     old: $($b -join ' | ')" }
        }
        Write-Host ("{0}: {1} team lineups differ" -f $f.BaseName, $dTeams); $lines | ForEach-Object { Write-Host $_ }
        $totalDiff += $dTeams
        continue
    }
    New-Item -ItemType Directory -Force -Path $lineupDir | Out-Null
    $pairings = @(@($doc.matches) | Where-Object { @($_.teams).Count -eq 2 } | ForEach-Object { [ordered]@{ a = @($_.teams)[0].teamId; b = @($_.teams)[1].teamId } })
    $out = [ordered]@{ date = $f.BaseName; _help = "Generated from the public score sheets by scripts\Import-ScoreSheets.ps1 (seat order, blind/sub/vacant flags and averages are exactly as scored)."; matchups = $pairings; teams = $teamsOut }
    [IO.File]::WriteAllText((Join-Path $lineupDir "$($f.BaseName).json"), ($out | ConvertTo-Json -Depth 10 -Compress), [Text.UTF8Encoding]::new($true))
    $laneDoc.weeks | Add-Member -Force $f.BaseName @($laneRows | ForEach-Object { [pscustomobject]$_ })
    Write-Host ("{0}: {1} teams, {2} lane pairs" -f $f.BaseName, $teamsOut.Count, $laneRows.Count)
}
if (-not $Compare) { $laneDoc | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 $lanesFile }
if ($Compare) { Write-Host "TOTAL team lineups that differ from the existing files: $totalDiff" }
if ($notes.Count) { Write-Host "`nSeats worth a look ($($notes.Count)):"; $notes | Select-Object -First 25 | ForEach-Object { Write-Host "  $_" } }
if ($unknown.Count) { Write-Warning "$($unknown.Count) name(s) not found in $snapDir team files (nickname/rename/left league?):"; $unknown | Select-Object -Unique | Select-Object -First 25 | ForEach-Object { Write-Warning "  $_" } }
if ($hdMismatch) { Write-Host "(handicap formula disagreed with the sheet's handicap on $hdMismatch seat(s))" }
