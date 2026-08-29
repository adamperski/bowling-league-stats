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

# ---- handicap rule -----------------------------------------------------------
$hc      = $league.handicapRules
$hcBase  = [int]$hc.percentageOf       # 235
$hcPct   = [double]$hc.percentage / 100 # 0.90
$hcNeg   = [bool]$hc.allowNegative
function Get-Hdcp([double]$avg) {
    $h = [math]::Floor(($hcBase - $avg) * $hcPct)
    if ($h -lt 0 -and -not $hcNeg) { $h = 0 }
    [int]$h
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

    foreach ($b in $teamData) {
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
    }
    standings    = $teams
    bowlers      = $bowlers
    leaderboards = $ldr
    teamLeaderboards = $teamLdr
}
$json = $data | ConvertTo-Json -Depth 12 -Compress

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
