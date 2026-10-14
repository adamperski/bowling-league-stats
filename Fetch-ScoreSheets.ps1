<#
    Fetch-ScoreSheets.ps1

    Archives every week's public score sheets (the data behind LeaguePals'
    "Scores" page: seat order, lane, per-game blind/sub/vacant flags, handicaps,
    per-team points breakdown, and who each bowler faced in each game) into
    data\scoresheets\<slug>\<yyyy-MM-dd>.json, trimmed to what the build needs.

    This replaces printed recap reports / currentscores links for lineup order
    and lanes: it's a public endpoint (GET /recentScoresPublic), works for any
    past or current week, and doesn't expire.

    Usage:
        .\Fetch-ScoreSheets.ps1                       # current season: new weeks + the latest 2 (scores can be corrected)
        .\Fetch-ScoreSheets.ps1 -Season 2022-23       # a config.json pastSeasons entry (all weeks not yet saved)
        .\Fetch-ScoreSheets.ps1 -Season 2022-23 -Force  # re-fetch every week
#>
[CmdletBinding()]
param(
    [string]$Season,
    [switch]$Force,
    [int]$Recent = 2
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$cfg   = Get-Content -Raw (Join-Path $scriptDir 'config.json') | ConvertFrom-Json
$base  = $cfg.baseUrl.TrimEnd('/')
$delay = [double]$cfg.requestDelaySeconds
$ua    = 'bowling-league-stats/1.0 (personal league archive; contact adamperski@gmail.com)'

if ($Season) {
    $ps = @($cfg.pastSeasons | Where-Object { $_.slug -eq $Season })[0]
    if (-not $ps) { throw "No pastSeasons entry '$Season' in config.json" }
    $leagueId = $ps.leagueId; $slug = $Season
    $lfPath = Join-Path $scriptDir "data\seasons\$Season\league_full.json"
    $isCurrent = $false
} else {
    $leagueId = $cfg.leagueId; $slug = $cfg.seasonSlug; $isCurrent = $true
    $snap = Get-ChildItem (Join-Path $scriptDir 'data\raw') -Directory | Sort-Object Name -Descending | Select-Object -First 1
    $lfPath = Join-Path $snap.FullName 'league_full.json'
}
if (-not $slug) { throw 'config.json needs "seasonSlug" for the current season' }
if (-not (Test-Path $lfPath)) { throw "Need $lfPath - run Fetch-LeaguePals.ps1 first" }
$lf = (Get-Content -Raw $lfPath | ConvertFrom-Json).data

$outDir = Join-Path $scriptDir "data\scoresheets\$slug"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# The Scores page asks for one 7-day window per week, as epoch milliseconds from the
# league's start date (startOf day, UTC).
$start  = [DateTimeOffset]::Parse($lf.dateStart).UtcDateTime.Date
$end    = [DateTimeOffset]::Parse($lf.dateEnd).UtcDateTime.Date
$weeks  = [int][math]::Ceiling(($end - $start).TotalDays / 7) + 1
$nowUtc = [DateTime]::UtcNow
$existing = @(Get-ChildItem $outDir -Filter '*.json' | Sort-Object Name | ForEach-Object { $_.BaseName })
$refetch = if ($isCurrent -and $Recent -gt 0) { @($existing | Select-Object -Last $Recent) } else { @() }
Write-Host "=== score sheets: $slug ($leagueId), $weeks week windows, $($existing.Count) already saved ==="

function Flag($v) { if ($v) { $true } else { $null } }
function Trim-Match($m) {
    $teams = foreach ($t in @($m.teams)) {
        $players = $(foreach ($p in @($t.players)) {
            $games = foreach ($g in @($p.games)) {
                $o = [ordered]@{ p = $g.totalPins; a = $g.average; h = $g.handicap }
                if ($g.isBlind) { $o.b = 1 }; if ($g.isIncomplete) { $o.i = 1 }; if ($g.isBench) { $o.e = 1 }
                if ($g.isPartial) { $o.x = 1 }; if ($g.isSubstitute) { $o.s = 1 }; if ($g.isVacant) { $o.v = 1 }
                if ($g.subName) { $o.n = $g.subName }
                [pscustomobject]$o
            }
            $o = [ordered]@{ id = $p.bowler._id; name = $p.bowler.name; avg = $p.average; games = @($games) }
            if ($p.isSubstitute) { $o.sub = 1 }; if ($p.isVacant) { $o.vacant = 1 }; if ($p.isPartial) { $o.partial = 1 }
            [pscustomobject]$o
        })
        [pscustomobject][ordered]@{
            teamId = $t.team._id; team = $t.team.name; lane = $t.lane
            pins = $t.totalPins; total = $t.totalScore; points = $t.totalPoints; result = $t.matchWinLoss
            pts = [pscustomobject][ordered]@{ indGame = $t.individualGamePoints; teamGame = $t.teamGamePoints
                indSeries = $t.individualSeriesScorePoints; indSeriesAvg = $t.individualSeriesAvgPoints
                teamSeries = $t.teamSeriesScorePoints; teamSeriesAvg = $t.teamSeriesAvgPoints }
            players = @($players)
        }
    }
    $pairs = foreach ($b in @($m.individualPoints.bowlers)) {
        [pscustomobject][ordered]@{ pid = $b.player_id; pts = @($b.points); opp = @($b.opponents); oppSub = @($b.opponentSubs) }
    }
    [pscustomobject][ordered]@{
        id = $m._id; date = ([string]$m.date).Substring(0, 10); manual = [bool]$m.manual
        score = @($m.team1Score, $m.team2Score); teams = @($teams); pairs = @($pairs)
    }
}

$saved = 0; $empty = 0
for ($i = 0; $i -lt $weeks; $i++) {
    $min = [DateTimeOffset]::new($start.AddDays(7 * $i), [TimeSpan]::Zero).ToUnixTimeMilliseconds()
    $max = $min + 7 * 86400000 - 1
    $wkStart = $start.AddDays(7 * $i)
    if ($wkStart -gt $nowUtc) { break }
    # skip windows we already hold (a window's file is named by the matches' date, not the window start)
    $have = @($existing | Where-Object { [datetime]$_ -ge $wkStart -and [datetime]$_ -lt $wkStart.AddDays(7) })
    if ($have.Count -and -not $Force -and -not ($have | Where-Object { $refetch -contains $_ })) { continue }
    $url = "$base/recentScoresPublic?leagueId=$leagueId&minDate=$min&maxDate=$max&weekIdx=0"
    Write-Host ("GET week {0,2} ({1:yyyy-MM-dd})" -f ($i + 1), $wkStart)
    $r = Invoke-WebRequest -Uri $url -Headers @{ 'User-Agent' = $ua } -UseBasicParsing -TimeoutSec 300
    $matches = @(($r.Content | ConvertFrom-Json).data)
    if (-not $matches.Count) { Write-Host '   (no matches this week)'; $empty++; Start-Sleep -Seconds $delay; continue }
    $trimmed = @($matches | ForEach-Object { Trim-Match $_ })
    $date = $trimmed[0].date
    $doc = [pscustomobject][ordered]@{ league = $leagueId; slug = $slug; date = $date; fetchedAt = (Get-Date).ToString('o'); matches = $trimmed }
    $file = Join-Path $outDir "$date.json"
    [IO.File]::WriteAllText($file, ($doc | ConvertTo-Json -Depth 12 -Compress), [Text.UTF8Encoding]::new($false))
    Write-Host ("   saved {0}: {1} matches, {2:N0} KB" -f $date, $trimmed.Count, ((Get-Item $file).Length / 1KB))
    $saved++
    Start-Sleep -Seconds $delay
}
Write-Host "Done. $saved week(s) saved, $empty empty window(s) -> $outDir"
