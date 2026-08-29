# Pioneer I 2026-2027 - League Stats

Tools to archive and analyze data for the **Pioneer I 2026-2027** league at
**Lucky Strike Wheat Ridge**, tracked on LeaguePals.

## How the data gets here

LeaguePals has no official public API, but the pages under
`leaguepals.com/league-info` are driven by a handful of **public, no-login JSON
endpoints**. `Fetch-LeaguePals.ps1` calls them and saves the raw responses.

| File written | Source endpoint | What's in it |
|---|---|---|
| `league.json` | `/getLeaguePublic?id=` | Full league config: handicap rule, points rule, blind/vacancy scores, min games |
| `league_full.json` | `/fullLeagueInfoPublic?id=` | Schedule, season dates, teams, per-team season totals |
| `standings.json` | `/api/getStandingsPublic?leagueId=` | Every team: points won/lost/tied, games, pins, average; every bowler's games by week |
| `standings_split{0..3}.json` | same, `&split=N` | Same, scoped to each half/segment of the season |
| `tops.json` | `/api/getTopsPublic` (POST) | Leaderboards: high team/individual game & series, individual points, top averages |
| `team_<name>__<id>.json` | `/api/loadIndividualTeamPublic?id=<teamId>` | Per bowler: real name, every game, series, `individualPoints`, high game/series (scratch + hcp) |
| `_manifest.json` | (generated) | Snapshot date, team list |

### Individual data caveat

The league's public **individual leaderboards are turned off**
(`tops.json` -> `topIndividual*` come back empty), and `standings.json` masks
bowler emails. Real per-bowler names and scores still come through
`team_*.json` (`loadIndividualTeamPublic`), which is what we rely on.

## Usage

Run once after league night (Tuesdays):

```powershell
powershell -ExecutionPolicy Bypass -File .\Fetch-LeaguePals.ps1
```

Backfill or re-pull a specific date:

```powershell
powershell -ExecutionPolicy Bypass -File .\Fetch-LeaguePals.ps1 -Date 2026-09-08
```

Each run writes a new dated folder under `data\raw\`. Runs are additive - the
folder is a permanent archive that survives any future change on LeaguePals'
side. **Commit `data\raw\` to git** (or back it up) so nothing is ever lost.

## The 40-point week (from `league.json`)

| Contest | Points | Basis |
|---|---|---|
| Individual game (x3) | 1 each | your handicap game vs the opposing bowler in your lineup slot |
| Individual series | 2 | your handicap series vs that same bowler |
| Team game (x3) | 3 each | team handicap game vs the other team |
| Team series | 6 | team handicap series vs the other team |

`5 bowlers x (3x1 + 2) + (3x3 + 6) = 25 + 15 = 40`

- Handicap = `(235 - average) x 90%`, not below 0, based on all-inclusive average.
- `fullPointsAmongTeammates = false` -> individual points are head-to-head vs the
  one opposing bowler in the same position, not vs the whole other team.
- Bowling against a blind (absent) bowler: opponent scores avg then adjusted;
  `blindTeamCantWinPoints = true`.
- Season runs 2026-08-18 -> 2027-04-27. The first weeks may be establishing
  averages (`minGamesforAvg = 12`, `previousGamesMin = 21`) before points count.

## Build the stats + dashboard

```powershell
powershell -ExecutionPolicy Bypass -File .\Build-Stats.ps1
```

Reads the newest snapshot under `data\raw\` (or pass `-Date 2026-09-08`) and writes:

- `data\out\<date>\bowlers.csv` - one row per bowler: book avg, season avg,
  +/-, games, high game/series (scratch + handicap), std-dev, individual points.
- `data\out\<date>\bowler_weeks.csv` - one row per bowler per week: the 3 games,
  series, whether it counts.
- `data\out\<date>\teams.csv` - standings with points, record, team avg/handicap, roster.
- `data\out\<date>\leaderboards.csv` - every leaderboard flattened.
- `dashboard.html` - a **self-contained** page (no server, no internet). Open it
  in any browser. Tabs: Standings / Leaderboards / Averages / Bowlers / Teams.
  Sortable tables; click a bowler or team row to expand week-by-week detail.
  Also copied to `data\out\<date>\dashboard.html`.

`dashboard.template.html` is the layout/JS; `Build-Stats.ps1` injects the data.
Edit the template to change how the dashboard looks.

### Weekly routine

```powershell
powershell -ExecutionPolicy Bypass -File .\Fetch-LeaguePals.ps1
powershell -ExecutionPolicy Bypass -File .\Build-Stats.ps1
git add data/raw && git commit -m "week of <date>"
```

## The archive is a git repo

`data\raw\` is committed to git so every week's snapshot is version-controlled
and recoverable. Generated files (`data\out\`, `dashboard.html`) are gitignored -
they rebuild from the raw data any time.

## Config

Edit `config.json` to point at a different league (the `leagueId` is the `id=`
in the `league-info` URL).

## Known nuance

Within a week, LeaguePals stores the 3 games in the order it stores them; the
dashboard shows them as stored. Totals, averages, and highs are unaffected.

## Ideas for later

- Head-to-head: which bowler/team you faced each week (derivable from the
  `matches` list in `league_full.json` + `match_id` in each week's games).
- Points pace / projected final standings once weeks start counting.
- Publish `dashboard.html` as a shareable link instead of emailing the file.
