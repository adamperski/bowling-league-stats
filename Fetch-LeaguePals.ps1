<#
    Fetch-LeaguePals.ps1

    Takes a dated snapshot of one LeaguePals league using only the public
    (no-login) endpoints that power leaguepals.com/league-info, and writes the
    raw JSON to data\raw\<yyyy-MM-dd>\.

    Run it once after league night. Every run is additive - you are building a
    permanent week-by-week archive that survives any future change on their end.

    Usage:
        powershell -ExecutionPolicy Bypass -File .\Fetch-LeaguePals.ps1
        powershell -ExecutionPolicy Bypass -File .\Fetch-LeaguePals.ps1 -Date 2026-09-02

    No dependencies. Windows PowerShell 5.1 is fine.
#>
[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
             elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
             else { (Get-Location).Path }
if (-not $ConfigPath) { $ConfigPath = Join-Path $scriptDir 'config.json' }

$cfg      = Get-Content -Raw $ConfigPath | ConvertFrom-Json
$base     = $cfg.baseUrl.TrimEnd('/')
$leagueId = $cfg.leagueId
$delay    = [double]$cfg.requestDelaySeconds
$ua       = 'bowling-league-stats/1.0 (personal league archive; contact adamperski@gmail.com)'

$outDir = Join-Path $scriptDir (Join-Path 'data\raw' $Date)
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Save-Json {
    param([string]$Name, [string]$Text)
    $path = Join-Path $outDir "$Name.json"
    # Round-trip so a malformed body fails loudly instead of poisoning the archive.
    $null = $Text | ConvertFrom-Json
    [IO.File]::WriteAllText($path, $Text, [Text.UTF8Encoding]::new($false))
    $kb = [math]::Round(($Text.Length / 1KB), 1)
    Write-Host ("  saved {0,-34} {1,8} KB" -f "$Name.json", $kb)
}

function Get-Public {
    param([string]$Name, [string]$Url)
    Write-Host "GET  $Url"
    $r = Invoke-WebRequest -Uri $Url -Method GET -Headers @{ 'User-Agent' = $ua } -UseBasicParsing
    Save-Json -Name $Name -Text $r.Content
    Start-Sleep -Seconds $delay
}

function Post-Public {
    param([string]$Name, [string]$Url, $Body)
    $json = $Body | ConvertTo-Json -Compress
    Write-Host "POST $Url  $json"
    $r = Invoke-WebRequest -Uri $Url -Method POST -Body $json -ContentType 'application/json' `
                           -Headers @{ 'User-Agent' = $ua } -UseBasicParsing
    Save-Json -Name $Name -Text $r.Content
    Start-Sleep -Seconds $delay
}

Write-Host "=== $($cfg.leagueName) @ $($cfg.center) ==="
Write-Host "Snapshot: $Date"
Write-Host "Output:   $outDir`n"

# 1. League configuration + full schedule / roster
Get-Public  -Name 'league'            -Url "$base/getLeaguePublic?id=$leagueId"
Get-Public  -Name 'league_full'       -Url "$base/fullLeagueInfoPublic?id=$leagueId"

# 2. Which season half ("split") is current
Get-Public  -Name 'current_split'     -Url "$base/getCurrentSplitByLeagueId?id=$leagueId&withTime=true&today=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"

# 3. Team standings - one call returns the whole season, including every
#    bowler's per-week games, team points won/lost/tied, and split points.
Get-Public  -Name 'standings'         -Url "$base/api/getStandingsPublic?leagueId=$leagueId"

# 3b. Also grab each split explicitly, but keep only the ones that actually
#     differ from the default pull (most leagues have a single split).
$defaultStandings = [IO.File]::ReadAllText((Join-Path $outDir 'standings.json'))
foreach ($split in 0..3) {
    try {
        Get-Public -Name "standings_split$split" -Url "$base/api/getStandingsPublic?leagueId=$leagueId&split=$split&weekIdx=0"
        $p = Join-Path $outDir "standings_split$split.json"
        if ([IO.File]::ReadAllText($p) -eq $defaultStandings) {
            Remove-Item $p
            Write-Host "  (split $split identical to default - removed)"
        }
    } catch {
        Write-Host "  (split $split not available - skipping)"
    }
}

# 4. Leaderboards (high team/individual game & series, individual points, top averages)
Post-Public -Name 'tops'              -Url "$base/api/getTopsPublic" -Body @{ leagueId = $leagueId }

# 5. Per-team detail: real bowler names, every game, individualPoints, high game/series.
$standings = Get-Content -Raw (Join-Path $outDir 'standings.json') | ConvertFrom-Json
$teams = @()
foreach ($row in $standings.data.standings) {
    if ($row.team -and $row.team._id) {
        $teams += [pscustomobject]@{ id = $row.team._id; name = $row.team.name }
    }
}
$teams = $teams | Sort-Object id -Unique
Write-Host "`n$($teams.Count) teams:"
foreach ($t in $teams) {
    $safe = ($t.name -replace '[^\w\- ]', '').Trim() -replace '\s+', '_'
    if (-not $safe) { $safe = 'team' }
    Get-Public -Name "team_${safe}__$($t.id)" -Url "$base/api/loadIndividualTeamPublic?id=$($t.id)"
}

# 6. Manifest for this snapshot
$manifest = [pscustomobject]@{
    date       = $Date
    fetchedAt  = (Get-Date).ToString('o')
    leagueId   = $leagueId
    leagueName = $cfg.leagueName
    center     = $cfg.center
    teamCount  = $teams.Count
    teams      = $teams
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $outDir '_manifest.json')

Write-Host "`nDone. $($teams.Count + 6) files in $outDir"
