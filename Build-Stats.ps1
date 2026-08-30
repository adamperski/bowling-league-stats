<#
    Build-Stats.ps1

    Reads the most recent snapshot under data\raw\ (or -Date / -SnapshotDir),
    flattens it into tidy CSVs under data\out\<date>\, and regenerates a
    self-contained dashboard.html (no server, no internet - just open it).

    Usage:
        powershell -ExecutionPolicy Bypass -File .\Build-Stats.ps1
        powershell -ExecutionPolicy Bypass -File .\Build-Stats.ps1 -Date 2026-09-08
#>
[CmdletBinding()]
param(
    [string]$Date,
    [string]$SnapshotDir,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
             elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
             else { (Get-Location).Path }
if (-not $ConfigPath) { $ConfigPath = Join-Path $scriptDir 'config.json' }
$cfg = Get-Content -Raw $ConfigPath | ConvertFrom-Json

$rawRoot = Join-Path $scriptDir 'data\raw'
if (-not $SnapshotDir) {
    if ($Date) {
        $SnapshotDir = Join-Path $rawRoot $Date
    } else {
        $latest = Get-ChildItem $rawRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if (-not $latest) { throw "No snapshots found under $rawRoot. Run Fetch-LeaguePals.ps1 first." }
        $SnapshotDir = $latest.FullName
    }
}
if (-not (Test-Path $SnapshotDir)) { throw "Snapshot folder not found: $SnapshotDir" }
$snapDate = Split-Path $SnapshotDir -Leaf
Write-Host "Building from snapshot: $snapDate"

function Read-Json($name) { Get-Content -Raw (Join-Path $SnapshotDir "$name.json") | ConvertFrom-Json }

$leagueId  = $cfg.leagueId
$league    = (Read-Json 'league').data
$leagueF   = (Read-Json 'league_full').data
$standings = (Read-Json 'standings').data
$tops      = (Read-Json 'tops').data
$topAll    = if ($tops.all) { $tops.all } else { $tops }

# ---- handicap + points rules ----------------------------------------------
$hc      = $league.handicapRules
$hcBase  = [int]$hc.percentageOf       # 235
$hcPct   = [double]$hc.percentage / 100 # 0.90
$hcNeg   = [bool]$hc.allowNegative
function Get-Hdcp([double]$avg) {
    $h = [math]::Floor(($hcBase - $avg) * $hcPct)
    if ($h -lt 0 -and -not $hcNeg) { $h = 0 }
    [int]$h
}

# Points per contest (from league config). Default to the classic 1/2/3/6 split.
$ptIndGame  = if ($league.pointsAwardedGame)     { [double]$league.pointsAwardedGame }     else { 1 }
$ptIndSer   = if ($league.pointsAwardedWood)     { [double]$league.pointsAwardedWood }     else { 2 }
$ptTeamGame = if ($league.teamPointsAwardedGame) { [double]$league.teamPointsAwardedGame } else { 3 }
$ptTeamSer  = if ($league.teamPointsAwardedWood) { [double]$league.teamPointsAwardedWood } else { 6 }

function Award($a, $b, $pts) {
    # Returns [pointsForA, pointsForB].
    $half = $pts / 2
    if ($a -gt $b)     { return @($pts, 0) }
    if ($b -gt $a)     { return @(0, $pts) }
    return @($half, $half)
}

# ---- season / week context -------------------------------------------------
$seasonStart = [datetime]$leagueF.dateStart
$seasonEnd   = [datetime]$leagueF.dateEnd
$today       = Get-Date
$weekNum     = [math]::Max(1, [math]::Floor(($today - $seasonStart).TotalDays / 7) + 1)

function Stat-StdDev($nums) {
    $n = @($nums).Count
    if ($n -lt 2) { return $null }
    $mean = ($nums | Measure-Object -Average).Average
    $var  = ($nums | ForEach-Object { ($_ - $mean) * ($_ - $mean) } | Measure-Object -Sum).Sum / $n
    [math]::Round([math]::Sqrt($var), 1)
}

# ---- team roster + standings lookup --------------------------------------
$teamById = @{}
foreach ($row in $standings.standings) {
    if (-not $row.team._id) { continue }
    $teamById[$row.team._id] = $row
}

# ---- bowlers ---------------------------------------------------------------
$bowlers = New-Object System.Collections.ArrayList
$anyCounting = $false

Get-ChildItem $SnapshotDir -Filter 'team_*.json' | ForEach-Object {
    $teamData = (Get-Content -Raw $_.FullName | ConvertFrom-Json).data
    # teamId is the trailing __<id> in the filename
    $teamId = ($_.BaseName -split '__')[-1]
    $srow   = $teamById[$teamId]
    $teamName = if ($srow) { $srow.team.name } else { ($_.BaseName -replace '^team_','' -replace '__.*$','') -replace '_',' ' }

    $rosterPos = -1
    foreach ($b in $teamData) {
        $rosterPos++
        $rec = $b.averages | Where-Object { $_.league -eq $leagueId } | Select-Object -First 1
        $bookAvg = if ($rec -and $rec.average) { [int]$rec.average } elseif ($b.average) { [int]$b.average } else { 0 }

        $display = $b.name
        if ($b.useNickname -and $b.nickNames -and $b.nickNames[0]) { $display = $b.nickNames[0] }
        if ($b.dontIdentify) {
            $fi = if ($b.firstName) { $b.firstName.Substring(0,1) } else { '?' }
            $li = if ($b.lastName)  { $b.lastName.Substring(0,1) }  else { '?' }
            $display = "$fi.$li."
        }

        $weeks = New-Object System.Collections.ArrayList
        $allGames = New-Object System.Collections.ArrayList
        foreach ($p in $b.weekGames.PSObject.Properties) {
            foreach ($wk in @($p.Value)) {
                # raw = [g1, g2, g3, tail]; "-" = game not bowled.
                # tail = scratch(bowled) + perGameHandicap * (#games bowled).
                $raw = @($wk.games)
                $gs = @($raw[0..([math]::Max(0, $raw.Count - 2))] |
                        Where-Object { $_ -ne '-' -and $_ -ne $null } | ForEach-Object { [int]$_ })
                $tail   = if ($raw.Count -ge 4) { [int]$raw[-1] } else { 0 }
                $scrSer = ($gs | Measure-Object -Sum).Sum
                $wkHdcp = if ($gs.Count -gt 0 -and $tail -ge $scrSer) {
                              [int][math]::Round(($tail - $scrSer) / $gs.Count)
                          } else { $null }
                $absent  = ($gs.Count -eq 0)
                $partial = (-not $absent -and $gs.Count -lt 3)
                foreach ($g in $gs) { [void]$allGames.Add($g) }
                if ($wk.isMatch) { $script:anyCounting = $true }
                [void]$weeks.Add([pscustomobject]@{
                    date    = $p.Name
                    weekIdx = [int]$wk.weekIdx
                    isMatch = [bool]$wk.isMatch
                    games   = $gs
                    scrSer  = $scrSer
                    hcpSer  = if ($tail -gt 0) { $tail } else { $scrSer }
                    wkHdcp  = $wkHdcp
                    absent  = $absent
                    partial = $partial
                    matchId = [string]$wk.match_id
                })
            }
        }
        $weeks = @($weeks | Sort-Object date)

        $g = @($allGames)
        $gamesBowled = $g.Count
        $pins = ($g | Measure-Object -Sum).Sum
        $seasonAvg = if ($gamesBowled -gt 0) { [math]::Round($pins / $gamesBowled, 1) } else { $null }
        $highGame = if ($gamesBowled -gt 0) { ($g | Measure-Object -Maximum).Maximum } else { 0 }
        $lowGame  = if ($gamesBowled -gt 0) { ($g | Measure-Object -Minimum).Minimum } else { 0 }
        $seriesVals = @($weeks | Where-Object { -not $_.absent -and -not $_.partial } | ForEach-Object { $_.scrSer })
        $highSeries = if ($seriesVals.Count) { ($seriesVals | Measure-Object -Maximum).Maximum } else { 0 }
        # per-week handicap LeaguePals actually used (median of derived values)
        $hdcpSamples = @($weeks | Where-Object { $_.wkHdcp -ne $null } | ForEach-Object { [int]$_.wkHdcp } | Sort-Object)
        $wkHdcpEff = if ($hdcpSamples.Count) { $hdcpSamples[[int]([math]::Floor($hdcpSamples.Count / 2))] } else { $null }
        # No established average yet -> handicap is not meaningful.
        $hdcp = if ($wkHdcpEff -ne $null) { $wkHdcpEff }
                elseif ($bookAvg -gt 0) { Get-Hdcp $bookAvg }
                else { $null }

        [void]$bowlers.Add([pscustomobject]@{
            id             = $b._id
            name           = $display
            fullName       = $b.name
            team           = $teamName
            teamId         = $teamId
            rosterPos      = $rosterPos
            gender         = if ($b.isFemale) { 'F' } else { 'M' }
            junior         = [bool]$b.isJunior
            bookAvg        = $bookAvg
            seasonAvg      = $seasonAvg
            hdcp           = $hdcp
            gamesBowled    = $gamesBowled
            totalPins      = $pins
            highGame       = [int]$highGame
            lowGame        = [int]$lowGame
            highSeries     = [int]$highSeries
            highGameHdcp   = if ($gamesBowled -gt 0 -and $hdcp -ne $null) { [int]$highGame + [int]$hdcp } else { 0 }
            highSeriesHdcp = if ($highSeries -gt 0 -and $hdcp -ne $null) { [int]$highSeries + 3 * [int]$hdcp } else { 0 }
            stdev          = Stat-StdDev $g
            improve        = if ($seasonAvg -ne $null) { [math]::Round($seasonAvg - $bookAvg, 1) } else { $null }
            indPoints      = if ($rec) { [double]$rec.individualPoints } else { 0 }
            compIndPoints  = 0.0
            weeks          = $weeks
        })
    }
}

# ---- teams ---------------------------------------------------------------
$teams = New-Object System.Collections.ArrayList
foreach ($row in $standings.standings) {
    if ($row.team.isBye -or $row.team.isPacer) { continue }
    $roster = @($bowlers | Where-Object { $_.teamId -eq $row.team._id })
    [void]$teams.Add([pscustomobject]@{
        id          = $row.team._id
        name        = $row.team.name
        wins        = [int]$row.wins
        losses      = [int]$row.losses
        ties        = [int]$row.ties
        games       = [int]$row.games
        pointsWon   = [double]$row.pointsWon
        pointsLost  = [double]$row.pointsLost
        pctWon      = [double]$row.pctWon
        teamAvg     = [int]$row.average
        teamHdcp    = ($roster | Measure-Object hdcp -Sum).Sum
        scratchPins = [int]$row.scratchPins
        totalPins   = [int]$row.totalPins
        roster      = @($roster | Sort-Object bookAvg -Descending | ForEach-Object { $_.name })
    })
}
$teams = @($teams | Sort-Object pointsWon -Descending)
for ($i = 0; $i -lt $teams.Count; $i++) { $teams[$i] | Add-Member rank ($i + 1) -Force }

# ---- leaderboards ------------------------------------------------------
$minG = 3
$elig = @($bowlers | Where-Object { $_.gamesBowled -ge $minG })
function Top($list, $prop, $n = 15, [switch]$Asc) {
    $s = if ($Asc) { $list | Sort-Object $prop } else { $list | Sort-Object $prop -Descending }
    @($s | Select-Object -First $n | ForEach-Object {
        [pscustomobject]@{ name = $_.name; team = $_.team; value = $_.$prop }
    })
}
$ldr = [ordered]@{
    highGame        = Top $elig 'highGame' 20
    highSeries      = Top $elig 'highSeries' 20
    highGameHdcp    = Top $elig 'highGameHdcp' 20
    highSeriesHdcp  = Top $elig 'highSeriesHdcp' 20
    topSeasonAvg    = Top $elig 'seasonAvg' 20
    topBookAvg      = Top ($bowlers | Where-Object { $_.bookAvg -gt 0 }) 'bookAvg' 20
    mostImproved    = Top $elig 'improve' 15
    mostDeclined    = Top $elig 'improve' 15 -Asc
    indPoints       = Top ($bowlers | Where-Object { $_.indPoints -gt 0 }) 'indPoints' 20
}
function TopsList($arr) {
    @($arr | ForEach-Object { [pscustomobject]@{ name = $_.name; value = $_.game; pos = $_.pos } })
}
$teamLdr = [ordered]@{
    teamGame       = TopsList $topAll.topTeamGame
    teamGameHdcp   = TopsList $topAll.topTeamGameHandicap
    teamSeries     = TopsList $topAll.topTeamSeries
    teamSeriesHdcp = TopsList $topAll.topTeamSeriesHandicap
    teamPoints     = @($teams | Select-Object -First 20 | ForEach-Object { [pscustomobject]@{ name = $_.name; value = $_.pointsWon } })
}

$weekDates = @($bowlers | ForEach-Object { $_.weeks } | ForEach-Object { $_.date } | Sort-Object -Unique)

# ---- head-to-head: reconstruct the schedule + matchup results ------------
# No public "match result" endpoint, so we rebuild it:
#   1. team roster POSITION is known: standings bowlerInfos are ordered and the
#      masked email "bowlerN@teamM" gives position N (0-4). Position i faces
#      position i (fullPointsAmongTeammates = false).
#   2. a team's match_id for a week = the id shared by the bowlers who actually
#      bowled (absentees keep a stale id) -> majority vote. Two teams sharing a
#      (week, match_id) are that matchup.
#   3. blanks are resolved to sub / blind / missed-game, with anything uncertain
#      written to data\lineups\<date>.json for manual review.
#   4. points recomputed from league rules + config.blindRules.
# When weeks start counting, LeaguePals' own pointsWon / individualPoints are
# authoritative; these stay a live/what-if view and a cross-check.

$br             = $cfg.blindRules
$blindDelta     = if ($br -and $br.deltaPerGame -ne $null) { [int]$br.deltaPerGame }
                  elseif ($league.againstBlindScore) { [int]$league.againstBlindScore } else { 10 }
$blindGetsHdcp  = -not ($br -and $br.getsHandicap -eq $false)
$blindStrict    = -not ($br -and $br.presentMustBeatStrictly -eq $false)
$blindToMatchup = -not ($br -and $br.blindPointsCountToMatchupTotal -eq $false)
$missUsesBlind  = -not ($br -and $br.missedGameUsesOwnAverageMinusDelta -eq $false)
$noAvgBlindFill = if ($league.vacancyScore) { [int]$league.vacancyScore } else { 150 }

function Blind-BaseAvg($avg) { if ([int]$avg -gt 0) { [int]$avg } else { $noAvgBlindFill } }

$bwWeek = @{}
$bowlerById = @{}
foreach ($b in $bowlers) {
    $bowlerById[$b.id] = $b
    foreach ($w in @($b.weeks)) {
        $kk = "$($b.id)|$($w.date)"
        $ex = $bwWeek[$kk]
        # a bowler can appear in two team files (regular + sub elsewhere) - keep the played week
        if (-not $ex -or ($ex.absent -and -not $w.absent)) { $bwWeek[$kk] = $w }
    }
}
$bowlerByName = @{}
foreach ($b in $bowlers) { if (-not $bowlerByName.ContainsKey($b.name)) { $bowlerByName[$b.name] = $b } }

# roster position per team (index in bowlerInfos, cross-checked against the email tag)
$teamRoster = @{}
foreach ($row in $standings.standings) {
    if (-not $row.team._id) { continue }
    $slots = @(); $i = 0
    foreach ($bi in $row.bowlerInfos) {
        $pos = if ("$($bi.email)" -match '^bowler(\d+)@') { [int]$Matches[1] } else { $i }
        $slots += [pscustomobject]@{ pos = $pos; id = $bi._id; avg = [int]$bi.average }
        $i++
    }
    $teamRoster[$row.team._id] = @($slots | Sort-Object pos)
}

function Get-Week($id, $date) { $bwWeek["$id|$date"] }
function Hdcp-Of($bw, $w) {
    if ($w -and $w.wkHdcp -ne $null) { return [int]$w.wkHdcp }
    if ($bw -and $bw.hdcp -ne $null) { return [int]$bw.hdcp }
    if ($bw -and $bw.bookAvg -gt 0) { return (Get-Hdcp $bw.bookAvg) }
    0
}

function New-BowlerSlot($pos, $name, $id, $w, $avg, $isSub) {
    $bw = if ($id) { $bowlerById[$id] } else { $null }
    $h = Hdcp-Of $bw $w
    $games = @(); $missFill = $false
    for ($g = 0; $g -lt 3; $g++) {
        if ($w -and $w.games.Count -gt $g -and $w.games[$g] -ne $null) { $games += [int]$w.games[$g] }
        elseif ($missUsesBlind -and $avg -gt 0) { $games += [int]($avg - $blindDelta); $missFill = $true }
        else { $games += $null; $missFill = $true }
    }
    $gh = @(); foreach ($x in $games) { $gh += $(if ($x -ne $null) { [int]$x + $h } else { $null }) }
    $scrSer = (@($games | Where-Object { $_ -ne $null }) | Measure-Object -Sum).Sum
    [pscustomobject]@{
        pos = [int]$pos; kind = $(if ($isSub) { 'sub' } elseif ($missFill) { 'partial' } else { 'bowler' })
        name = $name; id = $id; hdcp = [int]$h; games = $games; gameH = $gh
        scrSer = [int]$scrSer; serH = [int]$scrSer + 3 * [int]$h
        blind = $false; seasonEligible = (-not $isSub)
    }
}
function New-BlindSlot($pos, $regName, $avg) {
    $reg = $bowlerByName["$regName"]
    $base = Blind-BaseAvg $avg
    $h = if ($blindGetsHdcp) { if ([int]$avg -gt 0) { Hdcp-Of $reg $null } else { Get-Hdcp $base } } else { 0 }
    $per = [int]($base - $blindDelta)
    [pscustomobject]@{
        pos = [int]$pos; kind = 'blind'; name = "$regName (blind)"; id = $(if ($reg) { $reg.id } else { $null }); hdcp = [int]$h
        games = @($per, $per, $per); gameH = @(($per + $h), ($per + $h), ($per + $h))
        scrSer = 3 * $per; serH = 3 * $per + 3 * $h
        blind = $true; seasonEligible = $false
    }
}

function Build-AutoLineup($teamId, $date) {
    $roster = @($teamRoster[$teamId])
    $regIds = @($roster | ForEach-Object { $_.id })
    $subs = @($bowlers | Where-Object { $_.teamId -eq $teamId -and $regIds -notcontains $_.id } | ForEach-Object {
        $w = Get-Week $_.id $date; if ($w -and -not $w.absent) { $_ } })
    $flags = New-Object System.Collections.ArrayList
    $props = @()
    $open = @()
    foreach ($r in $roster) {
        $bw = $bowlerById[$r.id]; $w = Get-Week $r.id $date
        $slot = [ordered]@{ pos = $r.pos; kind = 'bowler'; name = $bw.name; id = $r.id; avg = $r.avg; subName = $null; subId = $null; subAvg = $null }
        if ($w -and -not $w.absent) {
            if ($w.partial) { $slot.kind = 'partial'; [void]$flags.Add("pos$($r.pos + 1) $($bw.name) bowled $($w.games.Count) of 3 - missing game(s) scored at avg-$blindDelta") }
        } else {
            $slot.kind = 'open'; $open += $slot
        }
        $props += [pscustomobject]$slot
    }
    $openSlots = @($props | Where-Object { $_.kind -eq 'open' } | Sort-Object pos)
    for ($k = 0; $k -lt $openSlots.Count; $k++) {
        $o = $openSlots[$k]
        if ($k -lt $subs.Count) {
            $s = $subs[$k]
            $o.kind = 'sub'; $o.subName = $s.name; $o.subId = $s.id; $o.subAvg = $s.bookAvg
            $conf = if ($subs.Count -eq 1 -and $openSlots.Count -eq 1) { 'confirm position' } else { 'GUESSED position - verify' }
            [void]$flags.Add("pos$($o.pos + 1) SUB $($s.name) (avg $($s.bookAvg)) for $($o.name) - $conf")
        } else {
            $o.kind = 'blind'
            $bl = (Blind-BaseAvg $o.avg) - $blindDelta
            $tag = if ([int]$o.avg -gt 0) { "avg $($o.avg)" } else { "NO established avg - using vacancy fill" }
            [void]$flags.Add("pos$($o.pos + 1) BLIND for $($o.name) ($tag, scores $bl/game +hdcp)")
        }
    }
    if ($subs.Count -gt $openSlots.Count) { [void]$flags.Add("$($subs.Count) subs present but only $($openSlots.Count) open position(s) - check lineup") }
    [pscustomobject]@{ slots = @($props | Sort-Object pos); flags = @($flags) }
}

# ---- match_id grouping -> pairings ----
$tmTally = @{}
foreach ($b in $bowlers) {
    foreach ($w in @($b.weeks)) {
        if ($w.absent -or -not $w.matchId) { continue }
        $k = "$($b.teamId)|$($w.date)"
        if (-not $tmTally.ContainsKey($k)) { $tmTally[$k] = @{} }
        if (-not $tmTally[$k].ContainsKey($w.matchId)) { $tmTally[$k][$w.matchId] = 0 }
        $tmTally[$k][$w.matchId]++
    }
}
$mg = @{}
foreach ($k in $tmTally.Keys) {
    $mid = ($tmTally[$k].GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
    $parts = $k -split '\|'
    $gk = "$($parts[1])|$mid"
    if (-not $mg.ContainsKey($gk)) { $mg[$gk] = New-Object System.Collections.ArrayList }
    [void]$mg[$gk].Add($parts[0])
}
$mDates = @($mg.Keys | ForEach-Object { ($_ -split '\|')[0] } | Sort-Object -Unique)

# ---- lineup review files (data\lineups\<date>.json) ----
$lineupDir = Join-Path $scriptDir 'data\lineups'
New-Item -ItemType Directory -Force -Path $lineupDir | Out-Null
$manualLineups = @{}   # "date|teamId" -> file entry
$resolvedMap   = @{}   # "date|teamId" -> bool
$reviews = New-Object System.Collections.ArrayList

foreach ($date in $mDates) {
    $file = Join-Path $lineupDir "$date.json"
    $teamIdsThatDate = @()
    foreach ($gk in $mg.Keys) { if (($gk -split '\|')[0] -eq $date) { $teamIdsThatDate += @($mg[$gk]) } }
    $teamIdsThatDate = @($teamIdsThatDate | Sort-Object -Unique)

    if (Test-Path $file) {
        $doc = Get-Content -Raw $file | ConvertFrom-Json
        foreach ($tp in $doc.teams.PSObject.Properties) {
            $tid = ($standings.standings | Where-Object { $_.team.name -eq $tp.Name } | Select-Object -First 1).team._id
            if (-not $tid) { continue }
            $manualLineups["$date|$tid"] = $tp.Value
            $resolvedMap["$date|$tid"] = [bool]$tp.Value.resolved
            if (-not $tp.Value.resolved) {
                [void]$reviews.Add([pscustomobject]@{ date = $date; team = $tp.Name; resolved = $false; flags = @($tp.Value.autoFlags) })
            }
        }
    } else {
        $teamsBlock = [ordered]@{}
        foreach ($tid in $teamIdsThatDate) {
            $auto = Build-AutoLineup $tid $date
            if (-not @($auto.flags).Count) { continue }
            $tname = $teamById[$tid].team.name
            $teamsBlock["$tname"] = [ordered]@{
                resolved  = $false
                autoFlags = @($auto.flags)
                lineup    = @($auto.slots | ForEach-Object {
                    [ordered]@{
                        pos      = $_.pos + 1
                        kind     = $_.kind
                        name     = if ($_.kind -eq 'sub') { $_.subName } else { $_.name }
                        blindFor = if ($_.kind -eq 'blind') { $_.name } else { $null }
                        subFor   = if ($_.kind -eq 'sub') { $_.name } else { $null }
                        avg      = if ($_.kind -eq 'sub') { $_.subAvg } else { $_.avg }
                    }
                })
            }
            [void]$reviews.Add([pscustomobject]@{ date = $date; team = $tname; resolved = $false; flags = @($auto.flags) })
        }
        if ($teamsBlock.Count) {
            ([ordered]@{
                date  = $date
                _help = "Weeks with a blind / sub / missed game. Fix each team's lineup (kind = bowler|partial|sub|blind), set resolved: true, re-run Build-Stats.ps1. Delete the file to regenerate."
                teams = $teamsBlock
            } | ConvertTo-Json -Depth 8) | Set-Content -Encoding utf8 $file
            Write-Host "  lineup review needed: $file"
        }
    }
}

function Resolve-Slots($teamId, $date) {
    $key = "$date|$teamId"
    $roster = @($teamRoster[$teamId])
    if ($manualLineups.ContainsKey($key)) {
        $out = @()
        foreach ($ln in @($manualLineups[$key].lineup)) {
            $pos0 = [int]$ln.pos - 1
            switch ("$($ln.kind)") {
                'blind' {
                    $rn = if ($ln.blindFor) { "$($ln.blindFor)" } else { "$($ln.name)" }
                    $reg = $roster | Where-Object { $bowlerById[$_.id].name -eq $rn } | Select-Object -First 1
                    $avg = if ($ln.avg) { [int]$ln.avg } elseif ($reg) { $reg.avg } else { 0 }
                    $out += New-BlindSlot $pos0 $rn $avg
                }
                'sub' {
                    $sb = $bowlerByName["$($ln.name)"]
                    $avg = if ($ln.avg) { [int]$ln.avg } elseif ($sb) { $sb.bookAvg } else { 0 }
                    $w = if ($sb) { Get-Week $sb.id $date } else { $null }
                    $out += New-BowlerSlot $pos0 "$($ln.name)" $(if ($sb) { $sb.id }) $w $avg $true
                }
                default {
                    $sb = $bowlerByName["$($ln.name)"]
                    $reg = $roster | Where-Object { $_.id -eq $sb.id } | Select-Object -First 1
                    $w = if ($sb) { Get-Week $sb.id $date } else { $null }
                    $out += New-BowlerSlot $pos0 "$($ln.name)" $(if ($sb) { $sb.id }) $w $(if ($reg) { $reg.avg } elseif ($sb) { $sb.bookAvg } else { 0 }) $false
                }
            }
        }
        return @($out | Sort-Object pos)
    }
    $auto = Build-AutoLineup $teamId $date
    $out = @()
    foreach ($s in $auto.slots) {
        if ($s.kind -eq 'blind') { $out += New-BlindSlot $s.pos $s.name $s.avg }
        elseif ($s.kind -eq 'sub') { $out += New-BowlerSlot $s.pos $s.subName $s.subId (Get-Week $s.subId $date) $s.subAvg $true }
        else { $out += New-BowlerSlot $s.pos $s.name $s.id (Get-Week $s.id $date) $s.avg $false }
    }
    @($out | Sort-Object pos)
}

function Beat($a, $b, $av, $bv, $pts, $tcw) {
    # -> @(aMatchupPts, bMatchupPts, aSeasonPts, bSeasonPts)
    # $tcw = winner of the matching TEAM contest ('A'/'B'/'T'); used when the
    # individual pairing can't be judged on its own (blind vs blind, or a game
    # missing on both sides) so every point is still awarded -> week totals 40.
    $aWin = $false; $bWin = $false; $tie = $false
    $useTeam = ($a.blind -and $b.blind) -or ($av -eq $null) -or ($bv -eq $null)
    if ($useTeam) {
        if ($tcw -eq 'A') { $aWin = $true } elseif ($tcw -eq 'B') { $bWin = $true } else { $tie = $true }
    }
    elseif ($a.blind -and -not $b.blind) { if ($blindStrict) { if ($bv -gt $av) { $bWin = $true } else { $aWin = $true } } else { if ($bv -ge $av) { $bWin = $true } else { $aWin = $true } } }
    elseif ($b.blind -and -not $a.blind) { if ($blindStrict) { if ($av -gt $bv) { $aWin = $true } else { $bWin = $true } } else { if ($av -ge $bv) { $aWin = $true } else { $bWin = $true } } }
    else { if ($av -gt $bv) { $aWin = $true } elseif ($bv -gt $av) { $bWin = $true } else { $tie = $true } }
    $ap = 0.0; $bp = 0.0
    if ($tie) { $ap = $pts / 2; $bp = $pts / 2 } elseif ($aWin) { $ap = $pts } elseif ($bWin) { $bp = $pts }
    $amt = $ap; $bmt = $bp
    if ($a.blind -and -not $blindToMatchup) { $amt = 0 }
    if ($b.blind -and -not $blindToMatchup) { $bmt = 0 }
    @($amt, $bmt, $(if ($a.seasonEligible) { $ap } else { 0 }), $(if ($b.seasonEligible) { $bp } else { 0 }))
}
function Win-Of($x, $y) { if ($x -gt $y) { 'A' } elseif ($y -gt $x) { 'B' } else { 'T' } }
function Compare-Slot($a, $b, $tgw, $tsw) {
    $r = @(0.0, 0.0, 0.0, 0.0)
    for ($g = 0; $g -lt 3; $g++) {
        $x = Beat $a $b $a.gameH[$g] $b.gameH[$g] $ptIndGame $tgw[$g]
        for ($j = 0; $j -lt 4; $j++) { $r[$j] += $x[$j] }
    }
    $x = Beat $a $b $a.serH $b.serH $ptIndSer $tsw
    for ($j = 0; $j -lt 4; $j++) { $r[$j] += $x[$j] }
    $r
}
function Team-Calc($slots) {
    $scr = @(0, 0, 0); $h = 0
    foreach ($s in $slots) {
        $h += [int]$s.hdcp
        for ($g = 0; $g -lt 3; $g++) { $v = $s.games[$g]; if ($v -eq $null) { $v = 0 }; $scr[$g] += [int]$v }
    }
    $ser = $scr[0] + $scr[1] + $scr[2]
    [pscustomobject]@{ scr = $scr; ser = $ser; hdcp = $h
        gameH = @(($scr[0] + $h), ($scr[1] + $h), ($scr[2] + $h)); serH = $ser + 3 * $h }
}

$schedule = New-Object System.Collections.ArrayList
foreach ($gk in ($mg.Keys | Sort-Object)) {
    $tids = @($mg[$gk])
    if ($tids.Count -ne 2) { continue }
    $date = ($gk -split '\|')[0]
    $A = $tids[0]; $B = $tids[1]
    $sa = @(Resolve-Slots $A $date); $sb = @(Resolve-Slots $B $date)
    if (-not $sa.Count -or -not $sb.Count) { continue }
    $ta = Team-Calc $sa; $tb = Team-Calc $sb

    # team contests (handicap) + their winners for blind-vs-blind fallback
    $tgw = @(); for ($g = 0; $g -lt 3; $g++) { $tgw += (Win-Of $ta.gameH[$g] $tb.gameH[$g]) }
    $tsw = Win-Of $ta.serH $tb.serH
    $aTeam = 0.0; $bTeam = 0.0
    for ($g = 0; $g -lt 3; $g++) { $r = Award $ta.gameH[$g] $tb.gameH[$g] $ptTeamGame; $aTeam += $r[0]; $bTeam += $r[1] }
    $r = Award $ta.serH $tb.serH $ptTeamSer; $aTeam += $r[0]; $bTeam += $r[1]

    $aInd = 0.0; $bInd = 0.0
    $pairs = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt 5; $i++) {
        $pa = $sa | Where-Object { $_.pos -eq $i } | Select-Object -First 1
        $pb = $sb | Where-Object { $_.pos -eq $i } | Select-Object -First 1
        if (-not $pa -or -not $pb) { continue }
        $c = Compare-Slot $pa $pb $tgw $tsw
        $aInd += $c[0]; $bInd += $c[1]
        if ($pa.id -and $pa.seasonEligible) { $bowlerById[$pa.id].compIndPoints += $c[2] }
        if ($pb.id -and $pb.seasonEligible) { $bowlerById[$pb.id].compIndPoints += $c[3] }
        [void]$pairs.Add([pscustomobject]@{
            aName = $pa.name; aId = $pa.id; aKind = $pa.kind; aGames = @($pa.games); aSer = $pa.scrSer; aHdcp = $pa.hdcp; aPts = $c[0]
            bName = $pb.name; bId = $pb.id; bKind = $pb.kind; bGames = @($pb.games); bSer = $pb.scrSer; bHdcp = $pb.hdcp; bPts = $c[1]
        })
    }
    $aTot = $aTeam + $aInd; $bTot = $bTeam + $bInd
    $revA = @($reviews | Where-Object { $_.date -eq $date -and $_.team -eq $teamById[$A].team.name })
    $revB = @($reviews | Where-Object { $_.date -eq $date -and $_.team -eq $teamById[$B].team.name })
    $flags = @(); $flags += @($revA | ForEach-Object { $_.flags }); $flags += @($revB | ForEach-Object { $_.flags })
    $kinds = @($sa + $sb | ForEach-Object { $_.kind }) | Sort-Object -Unique

    [void]$schedule.Add([pscustomobject]@{
        date        = $date
        counts      = [bool]($sa | Where-Object { $_.id } | ForEach-Object { (Get-Week $_.id $date).isMatch } | Where-Object { $_ } | Select-Object -First 1)
        estimated   = ($kinds -contains 'blind' -or $kinds -contains 'partial' -or $kinds -contains 'sub')
        needsReview = ($revA.Count -gt 0 -or $revB.Count -gt 0)
        flags       = @($flags)
        a = [pscustomobject]@{ team = $teamById[$A].team.name; teamId = $A; scr = $ta.scr; ser = $ta.ser; hdcp = $ta.hdcp; gameH = $ta.gameH; serH = $ta.serH; teamPts = $aTeam; indPts = $aInd; total = $aTot }
        b = [pscustomobject]@{ team = $teamById[$B].team.name; teamId = $B; scr = $tb.scr; ser = $tb.ser; hdcp = $tb.hdcp; gameH = $tb.gameH; serH = $tb.serH; teamPts = $bTeam; indPts = $bInd; total = $bTot }
        result      = if ($aTot -gt $bTot) { 'A' } elseif ($bTot -gt $aTot) { 'B' } else { 'T' }
        pairs       = $pairs
    })
}
$schedule = @($schedule | Sort-Object -Property date, @{ Expression = { $_.a.team } })
$reviewsOut = @($reviews | Sort-Object date, team)
Write-Host "  reconstructed $($schedule.Count) matchups across $($mDates.Count) weeks; $($reviewsOut.Count) lineup(s) need review"

# computed individual-points board (excludes points won as a blind) - populated above
$ldr['indPointsComp'] = Top (@($bowlers | Where-Object { $_.compIndPoints -gt 0 })) 'compIndPoints' 20

# ---- write CSVs ---------------------------------------------------------
$outDir = Join-Path $scriptDir (Join-Path 'data\out' $snapDate)
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$bowlers |
    Select-Object name, fullName, team, gender, junior, bookAvg, seasonAvg, hdcp, gamesBowled,
                  totalPins, highGame, lowGame, highSeries, highGameHdcp, highSeriesHdcp, stdev, improve, indPoints |
    Sort-Object team, name |
    Export-Csv (Join-Path $outDir 'bowlers.csv') -NoTypeInformation

$rows = foreach ($b in $bowlers) {
    foreach ($w in $b.weeks) {
        [pscustomobject]@{
            date = $w.date; weekIdx = $w.weekIdx; counts = $w.isMatch
            bowler = $b.name; team = $b.team
            g1 = $w.games[0]; g2 = $w.games[1]; g3 = $w.games[2]
            scratchSeries = $w.scrSer; hdcpSeries = $w.hcpSer
            absent = $w.absent; partial = $w.partial
        }
    }
}
$rows | Sort-Object date, team, bowler | Export-Csv (Join-Path $outDir 'bowler_weeks.csv') -NoTypeInformation

$teams |
    Select-Object rank, name, wins, losses, ties, pointsWon, pointsLost, pctWon, teamAvg, teamHdcp, scratchPins, totalPins,
                  @{n='roster';e={ $_.roster -join '; ' }} |
    Export-Csv (Join-Path $outDir 'teams.csv') -NoTypeInformation

$lbRows = foreach ($k in $ldr.Keys) { $ldr[$k] | ForEach-Object { [pscustomobject]@{ board = $k; name = $_.name; team = $_.team; value = $_.value } } }
$lbRows | Export-Csv (Join-Path $outDir 'leaderboards.csv') -NoTypeInformation

$schedule | ForEach-Object {
    [pscustomobject]@{
        date = $_.date; counts = $_.counts; estimated = $_.estimated; needsReview = $_.needsReview
        teamA = $_.a.team; teamB = $_.b.team
        aScratchSeries = $_.a.ser; bScratchSeries = $_.b.ser
        aHdcpSeries = $_.a.serH; bHdcpSeries = $_.b.serH
        aTeamPts = $_.a.teamPts; bTeamPts = $_.b.teamPts
        aIndPts = $_.a.indPts; bIndPts = $_.b.indPts
        aTotalPts = $_.a.total; bTotalPts = $_.b.total
        winner = if ($_.result -eq 'A') { $_.a.team } elseif ($_.result -eq 'B') { $_.b.team } else { 'tie' }
    }
} | Export-Csv (Join-Path $outDir 'matchups.csv') -NoTypeInformation

$pairRows = foreach ($m in $schedule) {
    foreach ($p in @($m.pairs)) {
        [pscustomobject]@{
            date = $m.date; teamA = $m.a.team; teamB = $m.b.team
            bowlerA = $p.aName; aKind = $p.aKind; aGames = (@($p.aGames) -join ' '); aSeries = $p.aSer; aHdcp = $p.aHdcp; aPts = $p.aPts
            bowlerB = $p.bName; bKind = $p.bKind; bGames = (@($p.bGames) -join ' '); bSeries = $p.bSer; bHdcp = $p.bHdcp; bPts = $p.bPts
        }
    }
}
$pairRows | Export-Csv (Join-Path $outDir 'headtohead_bowlers.csv') -NoTypeInformation

if ($reviewsOut.Count) {
    $reviewsOut | ForEach-Object {
        $d = $_.date; $t = $_.team
        foreach ($f in @($_.flags)) { [pscustomobject]@{ date = $d; team = $t; flag = $f } }
    } | Export-Csv (Join-Path $outDir 'lineup_review.csv') -NoTypeInformation
}

Write-Host "  CSVs -> $outDir"

# ---- build dashboard data + HTML --------------------------------------
$data = [ordered]@{
    meta = [ordered]@{
        league     = $cfg.leagueName
        center     = $cfg.center
        snapshot   = $snapDate
        generated  = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        seasonStart= $seasonStart.ToString('yyyy-MM-dd')
        seasonEnd  = $seasonEnd.ToString('yyyy-MM-dd')
        weekNum    = [int]$weekNum
        counting   = [bool]$anyCounting
        hcBase     = $hcBase
        hcPct      = $hc.percentage
        weekDates  = $weekDates
        pointsPerWeek = $cfg.pointsPerWeek
        favoriteTeam  = $cfg.favoriteTeam
        pts = [ordered]@{ indGame = $ptIndGame; indSeries = $ptIndSer; teamGame = $ptTeamGame; teamSeries = $ptTeamSer }
    }
    standings    = $teams
    bowlers      = $bowlers
    leaderboards = $ldr
    teamLeaderboards = $teamLdr
    schedule     = $schedule
    reviews      = $reviewsOut
}
$json = $data | ConvertTo-Json -Depth 25 -Compress

$tplPath = Join-Path $scriptDir 'dashboard.template.html'
$tpl = [IO.File]::ReadAllText($tplPath, [Text.UTF8Encoding]::new($false))
$html = $tpl.Replace('/*DATA*/', "window.LEAGUE_DATA = $json;")

$dashRepo = Join-Path $scriptDir 'dashboard.html'
[IO.File]::WriteAllText($dashRepo, $html, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $outDir 'dashboard.html'), $html, [Text.UTF8Encoding]::new($false))

Write-Host "  dashboard -> $dashRepo"
Write-Host "`nDone. $($bowlers.Count) bowlers, $($teams.Count) teams."
if (-not $anyCounting) {
    Write-Host "Note: no counting weeks yet - season is still in the average-establishing phase." -ForegroundColor Yellow
}
