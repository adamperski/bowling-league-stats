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
                $raw = @($wk.games)
                $series = if ($raw.Count -ge 4) { [int]$raw[-1] } else { 0 }
                $gs = @($raw[0..([math]::Max(0,$raw.Count-2))] | Where-Object { $_ -ne '-' -and $_ -ne $null } | ForEach-Object { [int]$_ })
                if ($raw.Count -lt 4) { $gs = @($raw | Where-Object { $_ -ne '-' } | ForEach-Object { [int]$_ }) }
                $absent = ($gs.Count -eq 0)
                foreach ($g in $gs) { [void]$allGames.Add($g) }
                if ($wk.isMatch) { $script:anyCounting = $true }
                [void]$weeks.Add([pscustomobject]@{
                    date    = $p.Name
                    weekIdx = [int]$wk.weekIdx
                    isMatch = [bool]$wk.isMatch
                    games   = $gs
                    series  = if ($series -gt 0) { $series } else { ($gs | Measure-Object -Sum).Sum }
                    absent  = $absent
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
        $seriesVals = @($weeks | Where-Object { -not $_.absent -and $_.games.Count -ge 3 } | ForEach-Object { $_.series })
        $highSeries = if ($seriesVals.Count) { ($seriesVals | Measure-Object -Maximum).Maximum } else { 0 }
        # No established average yet -> handicap is not meaningful.
        $hdcp = if ($bookAvg -gt 0) { Get-Hdcp $bookAvg } else { $null }

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
            highGameHdcp   = if ($gamesBowled -gt 0) { [int]$highGame + $hdcp } else { 0 }
            highSeriesHdcp = if ($highSeries -gt 0) { [int]$highSeries + 3 * $hdcp } else { 0 }
            stdev          = Stat-StdDev $g
            improve        = if ($seasonAvg -ne $null) { [math]::Round($seasonAvg - $bookAvg, 1) } else { $null }
            indPoints      = if ($rec) { [double]$rec.individualPoints } else { 0 }
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
# LeaguePals exposes no public "match result" endpoint, so we rebuild it:
#   1. each bowler's week carries a match_id; a team's real match_id for a week
#      is the one shared by the bowlers who actually bowled (absentees keep a
#      stale id), so we take the majority vote.
#   2. two teams sharing a (week, match_id) are that week's matchup.
#   3. team + individual points are recomputed from the league's own rules.
# Once weeks start counting, LeaguePals' pointsWon / individualPoints become the
# authoritative numbers; these stay useful as a live/what-if view and a check.

$bwWeek = @{}
foreach ($b in $bowlers) { foreach ($w in @($b.weeks)) { $bwWeek["$($b.id)|$($w.date)"] = $w } }

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
$teamWeekMatch = @{}
foreach ($k in $tmTally.Keys) {
    $teamWeekMatch[$k] = ($tmTally[$k].GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
}
$mg = @{}
foreach ($k in $teamWeekMatch.Keys) {
    $parts = $k -split '\|'
    $gk = "$($parts[1])|$($teamWeekMatch[$k])"
    if (-not $mg.ContainsKey($gk)) { $mg[$gk] = New-Object System.Collections.ArrayList }
    [void]$mg[$gk].Add($parts[0])
}

function Get-Lineup($teamId, $date) {
    @($bowlers | Where-Object { $_.teamId -eq $teamId } | ForEach-Object {
        $w = $bwWeek["$($_.id)|$date"]
        if ($w -and -not $w.absent) { [pscustomobject]@{ b = $_; w = $w } }
    } | Sort-Object { [int]$_.b.rosterPos })
}
function Side-Calc($entries) {
    $hdcp = 0; $miss = $false
    $scr = @(0, 0, 0)
    foreach ($e in $entries) {
        $hdcp += [int]$e.b.hdcp
        for ($g = 0; $g -lt 3; $g++) {
            if ($e.w.games.Count -gt $g -and $e.w.games[$g] -ne $null) { $scr[$g] += [int]$e.w.games[$g] }
            else { $miss = $true; $scr[$g] += [int]$e.b.bookAvg }   # rough blind fill
        }
    }
    $serScr = $scr[0] + $scr[1] + $scr[2]
    [pscustomobject]@{
        hdcp = $hdcp; scr = $scr; serScr = $serScr
        gameH = @(($scr[0] + $hdcp), ($scr[1] + $hdcp), ($scr[2] + $hdcp))
        serH = $serScr + (3 * $hdcp); est = $miss
    }
}

$schedule = New-Object System.Collections.ArrayList
foreach ($gk in ($mg.Keys | Sort-Object)) {
    $tids = @($mg[$gk])
    if ($tids.Count -ne 2) { continue }
    $date = ($gk -split '\|')[0]
    $A = $tids[0]; $B = $tids[1]
    $la = @(Get-Lineup $A $date); $lb = @(Get-Lineup $B $date)
    if (-not $la.Count -or -not $lb.Count) { continue }
    $ca = Side-Calc $la
    $cb = Side-Calc $lb

    $aTeam = 0.0; $bTeam = 0.0
    for ($g = 0; $g -lt 3; $g++) { $r = Award $ca.gameH[$g] $cb.gameH[$g] $ptTeamGame; $aTeam += $r[0]; $bTeam += $r[1] }
    $r = Award $ca.serH $cb.serH $ptTeamSer; $aTeam += $r[0]; $bTeam += $r[1]

    $aInd = 0.0; $bInd = 0.0
    $pairs = New-Object System.Collections.ArrayList
    $n = [math]::Min($la.Count, $lb.Count)
    for ($i = 0; $i -lt $n; $i++) {
        $ea = $la[$i]; $eb = $lb[$i]
        $ap = 0.0; $bp = 0.0
        for ($g = 0; $g -lt 3; $g++) {
            if ($ea.w.games.Count -le $g -or $eb.w.games.Count -le $g) { continue }
            $rr = Award ([int]$ea.w.games[$g] + [int]$ea.b.hdcp) ([int]$eb.w.games[$g] + [int]$eb.b.hdcp) $ptIndGame
            $ap += $rr[0]; $bp += $rr[1]
        }
        if ($ea.w.games.Count -ge 3 -and $eb.w.games.Count -ge 3) {
            $rr = Award ([int]$ea.w.series + 3 * [int]$ea.b.hdcp) ([int]$eb.w.series + 3 * [int]$eb.b.hdcp) $ptIndSer
            $ap += $rr[0]; $bp += $rr[1]
        }
        $aInd += $ap; $bInd += $bp
        [void]$pairs.Add([pscustomobject]@{
            aName = $ea.b.name; aId = $ea.b.id; aGames = @($ea.w.games); aSer = [int]$ea.w.series; aHdcp = [int]$ea.b.hdcp; aPts = $ap
            bName = $eb.b.name; bId = $eb.b.id; bGames = @($eb.w.games); bSer = [int]$eb.w.series; bHdcp = [int]$eb.b.hdcp; bPts = $bp
        })
    }
    $aTot = $aTeam + $aInd; $bTot = $bTeam + $bInd
    [void]$schedule.Add([pscustomobject]@{
        date      = $date
        counts    = [bool]$la[0].w.isMatch
        estimated = ($ca.est -or $cb.est -or $la.Count -ne $lb.Count)
        a = [pscustomobject]@{ team = $teamById[$A].team.name; teamId = $A; scr = $ca.scr; ser = $ca.serScr; hdcp = $ca.hdcp; gameH = $ca.gameH; serH = $ca.serH; teamPts = $aTeam; indPts = $aInd; total = $aTot; lineup = $la.Count }
        b = [pscustomobject]@{ team = $teamById[$B].team.name; teamId = $B; scr = $cb.scr; ser = $cb.serScr; hdcp = $cb.hdcp; gameH = $cb.gameH; serH = $cb.serH; teamPts = $bTeam; indPts = $bInd; total = $bTot; lineup = $lb.Count }
        result    = if ($aTot -gt $bTot) { 'A' } elseif ($bTot -gt $aTot) { 'B' } else { 'T' }
        pairs     = $pairs
    })
}
$schedule = @($schedule | Sort-Object -Property date, @{ Expression = { $_.a.team } })
Write-Host "  reconstructed $($schedule.Count) matchups across $(@($schedule | Select-Object -Expand date -Unique).Count) weeks"

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
            series = $w.series; absent = $w.absent
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
        date = $_.date; counts = $_.counts; estimated = $_.estimated
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
            bowlerA = $p.aName; aGames = (@($p.aGames) -join ' '); aSeries = $p.aSer; aHdcp = $p.aHdcp; aPts = $p.aPts
            bowlerB = $p.bName; bGames = (@($p.bGames) -join ' '); bSeries = $p.bSer; bHdcp = $p.bHdcp; bPts = $p.bPts
        }
    }
}
$pairRows | Export-Csv (Join-Path $outDir 'headtohead_bowlers.csv') -NoTypeInformation

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
