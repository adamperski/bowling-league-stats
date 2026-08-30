# Pioneer I 2026-2027 - League Stats

Tools to archive and analyze data for the **Pioneer I 2026-2027** league at
**Lucky Strike Wheat Ridge** (home team: **Sloppy Hookers**), tracked on LeaguePals.

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
  scratch & handicap series, absent / partial flags.
- `data\out\<date>\teams.csv` - standings with points, record, team avg/handicap, roster.
- `data\out\<date>\leaderboards.csv` - every leaderboard flattened.
- `data\out\<date>\matchups.csv` - one row per team-vs-team matchup: scratch &
  handicap series, team/individual/total points each side, winner, needs-review flag.
- `data\out\<date>\headtohead_bowlers.csv` - one row per position pairing:
  both bowlers' games, series, handicap, points, and kind (bowler/partial/sub/blind).
- `data\out\<date>\lineup_review.csv` - every unresolved sub/blind/missed-game flag.
- `dashboard.html` - a **self-contained** page (no server, no internet). Open it
  in any browser. Tabs: Standings / Head-to-Head / Leaderboards / Averages /
  Bowlers / Teams. Sortable tables; click a bowler, team, or matchup row to
  expand detail. Also copied to `data\out\<date>\dashboard.html`.

`dashboard.template.html` is the layout/JS; `Build-Stats.ps1` injects the data.
Edit the template to change how the dashboard looks.

### Weekly routine

If the GitHub Action is set up (see below), the Tuesday-night run does the fetch,
build, commit and publish for you. Your only job is to resolve any **Needs
Review** lineups it flags:

```powershell
git pull                                                   # get the auto-committed snapshot
# edit data\lineups\<date>.json - fix subs/blinds, set "resolved": true
powershell -ExecutionPolicy Bypass -File .\Build-Stats.ps1  # rebuild with your fixes
git add -A
git commit -m "resolve lineups, week of <date>"
git push                                                    # republishes automatically
```

Doing it entirely by hand (no Action):

```powershell
powershell -ExecutionPolicy Bypass -File .\Fetch-LeaguePals.ps1
powershell -ExecutionPolicy Bypass -File .\Build-Stats.ps1
# resolve Needs Review items, re-run Build-Stats.ps1
git add -A
git commit -m "week of <date>"
git push
```

## The archive is a git repo

`data\raw\` is committed to git so every week's snapshot is version-controlled
and recoverable. `dashboard.html` and `data\out\` are gitignored (they rebuild
from the raw data any time); `docs\index.html` and `data\lineups\` are committed.

## Publishing + auto-updating with GitHub Actions

`.github\workflows\league-site.yml` runs the whole pipeline in the cloud:

- **Tuesday ~10:30 PM Mountain** - pulls a fresh snapshot, rebuilds, commits it,
  publishes to GitHub Pages. (Two cron lines cover MDT and MST; the run with no
  new scores commits nothing.)
- **Any push to `main`** - rebuilds the dashboard from committed data and
  republishes (so your manual `git push` after resolving lineups goes live).
- **"Run workflow" button** - full pull + rebuild + publish on demand.

> The published site is **public and Google-indexable** (true even on a private
> repo, on the free/Pro plan). It shows 245 real names + scores. If that's not
> OK: don't enable Pages - just send people `dashboard.html` (self-contained),
> or use a password-protected host (Cloudflare Pages Access, Netlify).

### One-time setup on GitHub

1. **Settings -> Actions -> General -> Workflow permissions** -> "Read and write
   permissions" -> Save. (Lets the Tuesday run commit the new snapshot back.)
2. **Settings -> Pages -> Build and deployment -> Source: GitHub Actions.**
3. Push this repo (the workflow file has to be on `main` before it can run):
   ```
   git push
   ```
4. First publish: **Actions** tab -> **League site** -> **Run workflow** ->
   Branch `main` -> green **Run workflow**. ~3 min later the site is at
   `https://<you>.github.io/bowling-league-stats/`.

### Running it manually any time

**Actions** tab -> **League site** (left sidebar) -> **Run workflow** button
(right side) -> keep branch `main` -> **Run workflow**. Watch it under the runs
list; the `deploy` job's summary links the live URL.

The live site is always current. The `docs\index.html` committed in the repo
catches up on the next Tuesday run - or immediately if you run `Build-Stats.ps1`
locally before you push (the weekly routine below already does).

## Head-to-head (how the schedule is rebuilt)

LeaguePals has no public "match result" endpoint, so `Build-Stats.ps1`
reconstructs it:

1. **Position is known.** The standings feed lists each team's five bowlers in
   order and the masked email `bowlerN@teamM` gives position `N`. Position *i*
   faces position *i* (`fullPointsAmongTeammates = false`). No guessing for the
   regular five.
2. **Pairings.** Each bowler's week carries a `match_id`; a team's real id for a
   week is the one shared by the bowlers who actually bowled (absentees keep a
   stale id) - majority vote. Two teams sharing a `(week, match_id)` are that
   matchup.
3. **Points** (team 3/3/3/6, individual 1/1/1/2) are recomputed on the handicap
   scores. LeaguePals' 4th games value is `scratch + perGameHdcp x games`, so
   the per-week handicap is derived from it directly (more accurate than the
   formula, and it tracks the average as it moves).

Once real weeks count, LeaguePals' own `pointsWon` / `individualPoints` are
authoritative; the reconstruction stays a live/what-if view and a cross-check.

### Subs, blinds, missed games - the review workflow

Anything that isn't "all five regulars bowled three games" is auto-resolved as
best it can and written to **`data\lineups\<date>.json`**:

- **blind** - an absent regular with no sub. Blind score = that bowler's
  average - 10 per game, plus their handicap. The present opponent must beat it
  to take the point; if not, the point goes to the blind (it counts toward the
  matchup's 40 but **not** toward the blind bowler's season individual total).
- **sub** - a non-roster bowler who bowled. One sub + one open slot is
  auto-assigned; multiple are guessed and flagged. Sub bowls off their own book
  average.
- **partial** - a present bowler who missed a game; the missed game is scored at
  their own average - 10.
- **blind vs blind** - when both teams are missing the same position, those five
  individual points follow the matching team contest (team game 1 point -> team
  game 1 winner, etc.), so every week still totals 40.

The dashboard's **Needs Review** panel (top of Head-to-Head) lists every
unresolved case with the file to edit. Open `data\lineups\<date>.json`, fix the
`lineup` entries (swap a sub's `pos`, correct a `name`/`avg`, change a `kind`),
set that team's `"resolved": true`, and re-run `Build-Stats.ps1`. Your edits are
never overwritten; delete a file to regenerate it from scratch.

Blind behaviour is configurable in `config.json` -> `blindRules`.

`data\lineups\` is committed to git alongside `data\raw\` - it's your work, not
regenerable output.

## Config

Edit `config.json`:
- `leagueId` - the `id=` in the `league-info` URL (point at a different league).
- `favoriteTeam` - your team; the dashboard floats its matchups to the top and
  pre-selects it in the Head-to-Head pickers.
- `blindRules` - blind delta, whether the blind gets handicap, strict-beat, and
  whether blind points count toward the matchup total / season individual total.

## Known nuance

Within a week, LeaguePals stores the 3 games in the order it stores them; the
dashboard shows them as stored. Totals, averages, and highs are unaffected.

## Ideas for later

- Points pace / projected final standings once weeks start counting.
- Publish `dashboard.html` as a shareable link instead of emailing the file.
- Season-long H2H records table (all opponents at a glance).
