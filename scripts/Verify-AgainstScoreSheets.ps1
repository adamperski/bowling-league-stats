<#
    Verify-AgainstScoreSheets.ps1

    Checks the engine's reconstructed matchups against the official numbers in
    the public score sheets (data\scoresheets\<slug>\): for every matchup, each
    team's total points (and the team-contest / individual-contest split), its
    scratch series and handicap series; and whether seat N really faced seat N.

        .\scripts\Verify-AgainstScoreSheets.ps1                  # current season (needs a build: data\out\<snapshot>\matchups.csv)
        .\scripts\Verify-AgainstScoreSheets.ps1 -Season 2022-23  # a past season (needs its summary.json)
#>
[CmdletBinding()]
param([string]$Season, [int]$Show = 12)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$cfg = Get-Content -Raw (Join-Path $root 'config.json') | ConvertFrom-Json

# computed matchups, keyed "date|teamAId|teamBId" (both orders)
$comp = @{}
if ($Season) {
    $slug = $Season
    $sum = Get-Content -Raw (Join-Path $root "data\seasons\$Season\summary.json") | ConvertFrom-Json
    foreach ($m in @($sum.schedule)) {
        $r = [pscustomobject]@{ aId = $m.a.teamId; bId = $m.b.teamId; aPts = [double]$m.a.total; bPts = [double]$m.b.total
            aScr = [int]$m.a.ser; bScr = [int]$m.b.ser; aTot = [int]$m.a.serH; bTot = [int]$m.b.serH
            aTm = [double]$m.a.teamPts; bTm = [double]$m.b.teamPts; aInd = [double]$m.a.indPts; bInd = [double]$m.b.indPts; ovr = [bool]$m.officialOverride }
        $comp["$($m.date)|$($m.a.teamId)|$($m.b.teamId)"] = $r; $comp["$($m.date)|$($m.b.teamId)|$($m.a.teamId)"] = $r
    }
} else {
    $slug = $cfg.seasonSlug
    $out = (Get-ChildItem (Join-Path $root 'data\out') -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
    $snap = (Get-ChildItem (Join-Path $root 'data\raw') -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
    $st = (Get-Content -Raw (Join-Path $snap 'standings.json') | ConvertFrom-Json).data
    $idOf = @{}; foreach ($r in $st.standings) { if ($r.team._id) { $idOf[$r.team.name] = $r.team._id } }
    foreach ($m in (Import-Csv (Join-Path $out 'matchups.csv'))) {
        $a = $idOf[$m.teamA]; $b = $idOf[$m.teamB]
        $r = [pscustomobject]@{ aId = $a; bId = $b; aPts = [double]$m.aTotalPts; bPts = [double]$m.bTotalPts
            aScr = [int]$m.aScratchSeries; bScr = [int]$m.bScratchSeries; aTot = [int]$m.aHdcpSeries; bTot = [int]$m.bHdcpSeries
            aTm = [double]$m.aTeamPts; bTm = [double]$m.bTeamPts; aInd = [double]$m.aIndPts; bInd = [double]$m.bIndPts; ovr = ($m.officialOverride -eq 'True') }
        $comp["$($m.date)|$a|$b"] = $r; $comp["$($m.date)|$b|$a"] = $r
    }
}

$n = 0; $missing = 0; $overrides = 0
$ptsBad = 0; $scrBad = 0; $totBad = 0; $teamBad = 0; $indBad = 0
$seatsTot = 0; $seatsBad = 0
$bad = New-Object System.Collections.ArrayList; $seatBad = New-Object System.Collections.ArrayList
foreach ($f in (Get-ChildItem (Join-Path $root "data\scoresheets\$slug") -Filter '*.json' | Sort-Object Name)) {
    $doc = Get-Content -Raw $f.FullName | ConvertFrom-Json
    foreach ($m in @($doc.matches)) {
        $t = @($m.teams); if ($t.Count -ne 2) { continue }
        $n++
        $c = $comp["$($f.BaseName)|$($t[0].teamId)|$($t[1].teamId)"]
        if (-not $c) { $missing++; [void]$bad.Add("$($f.BaseName) $($t[0].team) v $($t[1].team): matchup not reconstructed"); continue }
        $sw = ($c.aId -ne $t[0].teamId)
        $cp = if ($sw) { @($c.bPts, $c.aPts) } else { @($c.aPts, $c.bPts) }
        $cs = if ($sw) { @($c.bScr, $c.aScr) } else { @($c.aScr, $c.bScr) }
        $ct = if ($sw) { @($c.bTot, $c.aTot) } else { @($c.aTot, $c.bTot) }
        $cm = if ($sw) { @($c.bTm, $c.aTm) } else { @($c.aTm, $c.bTm) }
        $ci = if ($sw) { @($c.bInd, $c.aInd) } else { @($c.aInd, $c.bInd) }
        if ($c.ovr) { $overrides++ }
        $why = @()
        for ($i = 0; $i -lt 2; $i++) {
            if ([double]$t[$i].points -ne $cp[$i]) { $why += "pts $($t[$i].team) $($cp[$i]) vs official $($t[$i].points)"; $ptsBad++ }
            if ([int]$t[$i].pins -ne $cs[$i]) { $why += "scratch $($t[$i].team) $($cs[$i]) vs $($t[$i].pins)"; $scrBad++ }
            if ([int]$t[$i].total -ne $ct[$i]) { $why += "hdcp series $($t[$i].team) $($ct[$i]) vs $($t[$i].total)"; $totBad++ }
            if (-not $c.ovr) {
                $offTeam = [double]$t[$i].pts.teamGame + [double]$t[$i].pts.teamSeries + [double]$t[$i].pts.teamSeriesAvg
                $offInd  = [double]$t[$i].pts.indGame + [double]$t[$i].pts.indSeries + [double]$t[$i].pts.indSeriesAvg
                if ($offTeam -ne $cm[$i]) { $why += "team-contest pts $($t[$i].team) $($cm[$i]) vs official $offTeam"; $teamBad++ }
                if ($offInd -ne $ci[$i]) { $why += "individual pts $($t[$i].team) $($ci[$i]) vs official $offInd"; $indBad++ }
            }
        }
        if ($why) { [void]$bad.Add("$($f.BaseName) $($t[0].team) v $($t[1].team): $($why -join '; ')") }

        # seat-by-seat: if seat N really faced seat N, the two bowlers' per-game points add to 1.
        # (A tie against a blind gives the present bowler 0.5 and the blind 0, so that one adds to 0.5.)
        $byPid = @{}; foreach ($pr in @($m.pairs)) { $byPid["$($pr.pid)"] = $pr }
        $pa = @($t[0].players); $pb = @($t[1].players)
        for ($s = 0; $s -lt [math]::Min($pa.Count, $pb.Count); $s++) {
            $ra = $byPid["$($pa[$s].id)"]; $rb = $byPid["$($pb[$s].id)"]
            if (-not $ra -or -not $rb) { continue }
            $seatsTot++; $okSeat = $true
            for ($g = 0; $g -lt 3; $g++) {
                $sumPts = [double]$ra.pts[$g] + [double]$rb.pts[$g]
                $ga = @($pa[$s].games)[$g]; $gb = @($pb[$s].games)[$g]
                $blindEither = [bool]($ga.b -or $gb.b -or $ga.v -or $gb.v)
                if ([math]::Abs($sumPts - 1) -gt 0.001 -and -not ($blindEither -and [math]::Abs($sumPts - 0.5) -lt 0.001)) { $okSeat = $false }
            }
            if (-not $okSeat) { $seatsBad++; [void]$seatBad.Add("$($f.BaseName) $($t[0].team) v $($t[1].team) seat $($s+1): $($pa[$s].name) [$($ra.pts -join ',')] + $($pb[$s].name) [$($rb.pts -join ',')]") }
        }
    }
}
"== $slug : $n matchups on the score sheets, $missing not reconstructed"
"   total points differing from official       : $ptsBad team-sides"
"   scratch series differing                   : $scrBad team-sides"
"   handicap series differing                  : $totBad team-sides"
"   team-contest pts differing: $teamBad ; individual-contest pts differing: $indBad  (team-sides)"
"   matchups shown with the sheet's official points because the rules can't reproduce them: $overrides"
"   seat pairing: $seatsTot seat pairs checked, $seatsBad where the two seats' points do NOT complement (i.e. not seat N vs seat N)"
if ($bad.Count) { "`nfirst mismatches:"; $bad | Select-Object -First $Show | ForEach-Object { "  $_" } }
if ($seatBad.Count) { "`nseat pairing exceptions:"; $seatBad | Select-Object -First $Show | ForEach-Object { "  $_" } }
