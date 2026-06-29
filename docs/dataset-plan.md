# Tiki-Taka-Toe — Dataset Clean, Merge & Local Storage Plan

## Purpose

This document is the **single source of truth** for how football trivia data is prepared for **Tiki-Taka-Toe** mode:

- What to **clean** and **merge** from `transfermarkt-datasets/`
- How to build the **shippable SQLite** database
- How the database connects to **game validation** (independent AND rule)
- How to avoid **impossible board** combinations

Raw CSV files are **build-time inputs only**. The Flutter app opens a **read-only** `tiki_taka.db` asset at runtime.

**Related:** [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md) (gameplay rules), `lib/features/tiki_taka/` implementation, home entry point.

---

## Game Validation Rule (Data Contract)

A submitted player is **valid** for a cell at row `R` and column `C` when:

```text
valid(player, attr_row, attr_col) ⇔
  player is linked to attr_row   (independently)
  AND player is linked to attr_col (independently)
```

Examples:

- Mohamed Salah → **Egypt** + **Liverpool**
- Jude Bellingham → **Carlo Ancelotti** (coach, future) + **Borussia Dortmund**
- Samuel Eto'o → **Premier League** (derived) + **Barcelona**

The database does **not** model “played under coach X at club Y.” It only stores **membership edges** between a player and each attribute.

---

## Source Baseline

Local path (not shipped in app):

```text
transfermarkt-datasets/
├── players.csv
├── clubs.csv
├── competitions.csv
├── countries.csv
├── transfers.csv
├── appearances.csv
├── national_teams.csv
├── games.csv              # optional until coach ETL
├── game_lineups.csv       # optional until coach ETL
├── club_games.csv         # out of scope v1
├── game_events.csv        # out of scope v1
└── player_valuations.csv # out of scope v1
```

Publisher: [transfermarkt-datasets](https://github.com/dcaribou/transfermarkt-datasets) (CC0 compilation). Personal project: use derived facts only; do **not** ship TM `image_url` or hotlink TM assets in UI.

### Key source columns

| File | Columns used in v1 |
| --- | --- |
| `players.csv` | `player_id`, `name`, `country_of_citizenship`, `position`, `sub_position`, `current_club_id` |
| `clubs.csv` | `club_id`, `name`, `domestic_competition_id` |
| `competitions.csv` | `competition_id`, `name`, `country_name` |
| `transfers.csv` | `player_id`, `from_club_id`, `to_club_id`, `transfer_date` |
| `appearances.csv` | `player_id`, `player_club_id`, `competition_id`, `date` |
| `national_teams.csv` | `national_team_id`, `name`, `country_name` |

### Top-5 league competition IDs (Transfermarkt)

| League | `competition_id` |
| --- | --- |
| Premier League | `GB1` |
| La Liga | `ES1` |
| Serie A | `IT1` |
| Bundesliga | `L1` |
| Ligue 1 | `FR1` |

---

## Target Architecture

```text
BUILD TIME (developer machine, repeat monthly)
  transfermarkt-datasets/*.csv
  tool/etl/config/*.yaml          # allowlists + aliases
  tool/etl/build_players.py       # D7 — players_table.csv
  tool/etl/fetch_player_images.py # D7b — player_images.csv (Wikidata; schema v2)
       ↓
  tool/etl/build_database.py      # D11 — merge → sqlite
       ↓
  tool/etl/output/tiki_taka.db
  tool/etl/output/manifest.json
       ↓ copy
  assets/db/tiki_taka.db          # Flutter asset (read-only)
```

**Player images:** See [player-image-plan.md](./player-image-plan.md) — [Maintainability & Future Updates](./player-image-plan.md#maintainability--future-updates) for full vs `--only-missing` refresh workflows.

```text
RUNTIME (Flutter)
  assets/db/tiki_taka.db
       → TikiTakaDatabase (open read-only)
       → Daos: search, validate, load board
       → TikiTakaGameEngine (3×3 marks, turns, win — no SQL)
       → UI
```

Match state (current player, cell marks, used players) lives **in memory** in the game engine/cubit, not in SQLite.

---

## Allowlists (v1 attributes)

ETL only emits attributes (and players) inside these lists. IDs are resolved from `clubs.csv` / `competitions.csv` / config YAML.

### Leagues (5)

Premier League, La Liga, Serie A, Bundesliga, Ligue 1 → `league:GB1` … `league:FR1`.

### Clubs (56)

Real Madrid, Barcelona, Atlético Madrid, Manchester United, Liverpool, Arsenal, Manchester City, Chelsea, Tottenham Hotspur, Newcastle United, Aston Villa, Everton, West Ham United, Brighton, Fulham, Brentford, Wolverhampton, Crystal Palace, Bayern Munich, Borussia Dortmund, Bayer Leverkusen, RB Leipzig, VfB Stuttgart, Eintracht Frankfurt, Union Berlin, Juventus, AC Milan, Inter Milan, Napoli, Roma, Lazio, Atalanta, Fiorentina, Bologna, Paris Saint-Germain, Monaco, Marseille, Lyon, Lille, Nice, Benfica, Porto, Sporting CP, Ajax, PSV Eindhoven, Galatasaray, Sevilla, Valencia, Villarreal, Copenhagen, Leeds United, Boca Juniors, Flamengo, Santos.

**ETL task:** maintain `tool/etl/config/clubs_allowlist.yaml` mapping **display name → `club_id`** (verified once against `clubs.csv`).

### Nations (25)

France, Spain, Argentina, England, Portugal, Brazil, Netherlands, Morocco, Belgium, Germany, Croatia, Italy, Colombia, Senegal, Mexico, United States, Uruguay, Japan, Switzerland, Denmark, Egypt, Algeria, Nigeria, Ivory Coast, Cameroon.

**Nation source v1:** `players.country_of_citizenship` (normalized). Optional v1.1: national-team appearances from `games` + `appearances` where competition is national-team.

**Alias examples:** `Cote d'Ivoire` → Ivory Coast; `United States` / `USA` unified.

### Positions (4)

Goalkeeper, Defender, Midfielder, Forward.

**TM → bucket mapping:**

| TM `position` / `sub_position` | Bucket |
| --- | --- |
| `Goalkeeper` | `pos:GK` |
| `Defender`, `Centre-Back`, `Left-Back`, `Right-Back`, … | `pos:DEF` |
| `Midfield`, `Defensive Midfield`, `Central Midfield`, `Attacking Midfield`, … | `pos:MID` |
| `Attack`, `Centre-Forward`, `Left Winger`, `Right Winger`, … | `pos:FWD` |

Unknown sub-positions: fall back to coarse `position` column; log warning in ETL report.

### Coaches (deferred)

Pep Guardiola, Sir Alex Ferguson, Carlo Ancelotti, Jürgen Klopp, José Mourinho, Zinedine Zidane, Diego Simeone, Luis Enrique, Antonio Conte, Arsène Wenger, Hans-Dieter Flick, Thomas Tuchel, Unai Emery, Lionel Scaloni, Didier Deschamps.

**Not in v1 SQLite.** Schema reserves `attributes.type = 'coach'` and `player_attributes.source = 'coach_match'`.

---

## Shippable SQLite Schema

File: `tiki_taka.db` (schema version in `meta` table).

### `meta`

| Column | Description |
| --- | --- |
| `key` | e.g. `schema_version`, `built_at`, `source_csv_hash` |
| `value` | string |

### `attributes`

Game-facing labels for board headers (clubs, nations, leagues, positions).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | `club:31`, `nation:egypt`, `league:GB1`, `pos:FWD` |
| `type` | TEXT | `club` \| `nation` \| `league` \| `position` |
| `display_name` | TEXT | UI label |
| `slug` | TEXT UNIQUE | stable key for config |
| `source_id` | TEXT | TM id when applicable |
| `icon_key` | TEXT | app asset key (not TM URL) |

### `players`

Subset of players with at least **two** allowlisted attribute links (after merge).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | `tm:{player_id}` |
| `display_name` | TEXT | |
| `search_text` | TEXT | lowercased, ASCII-folded for prefix search |
| `position` | TEXT | `GK` \| `DEF` \| `MID` \| `FWD` |
| `nation` | TEXT | normalized citizenship (cache) |
| `image_url` | TEXT NULL | HTTPS Commons thumbnail from Wikidata ETL; `NULL` when unresolved (schema v2) |
| `search_rank` | INTEGER NOT NULL DEFAULT 0 | Search ordering boost (schema v3); see below |

**Player image ETL:** `tool/etl/fetch_player_images.py` writes `staging/player_images.csv`; D11 merges into `image_url`. Maintainability runbook: [player-image-plan.md](./player-image-plan.md#maintainability--future-updates).

**Search rank (schema v3):** Computed at ETL in `tool/etl/search_rank.py` as `max(market_value, highest_market_value) + manual_boost`. Legendary players receive boosts via `tool/etl/config/legendary_search_rank_boost.yaml`. Runtime search orders by `search_rank DESC`, then prefix match preference (`player_search_dao.dart`).

### `player_attributes`

Core graph: **independent** edges used for AND validation.

| Column | Type | Notes |
| --- | --- | --- |
| `player_id` | TEXT | FK → `players.id` |
| `attribute_id` | TEXT | FK → `attributes.id` |
| `source` | TEXT | provenance (see below) |

**Primary key:** `(player_id, attribute_id, source)` — same edge from two sources may coexist until dedupe pass collapses for query (queries use `DISTINCT player_id`).

**`source` values v1:**

| `source` | Meaning |
| --- | --- |
| `transfer` | `from_club_id` or `to_club_id` in `transfers.csv` |
| `appearance` | `player_club_id` in `appearances.csv` |
| `citizenship` | `country_of_citizenship` on `players.csv` |
| `league_appearance` | appearance with `competition_id` in top-5 set |
| `league_club` | player at club whose `domestic_competition_id` is top-5 |

### `player_aliases` (recommended)

| Column | Type |
| --- | --- |
| `player_id` | TEXT |
| `alias` | TEXT (normalized) |

PK: `(player_id, alias)`. Seed from `name` + manual YAML overrides.

### `attribute_pair_stats` (precomputed)

Speeds board viability and QA.

| Column | Type |
| --- | --- |
| `attr_a` | TEXT |
| `attr_b` | TEXT |
| `player_count` | INTEGER |
| `sample_player_ids` | TEXT (JSON array, 5–10 ids) |

PK: `(attr_a, attr_b)`. Store both orderings or canonical `min(id)|max(id)`.

### `boards` + `board_slots`

| `boards` | |
| --- | --- |
| `id` | TEXT PK |
| `name` | TEXT |
| `min_intersection` | INTEGER (weakest cell on board) |

| `board_slots` | |
| --- | --- |
| `board_id` | TEXT |
| `slot_kind` | `row` \| `col` |
| `slot_index` | 0..2 |
| `attribute_id` | TEXT |

PK: `(board_id, slot_kind, slot_index)`.

### Indexes

```sql
CREATE INDEX idx_pa_attribute ON player_attributes(attribute_id);
CREATE INDEX idx_pa_player ON player_attributes(player_id);
CREATE INDEX idx_alias ON player_aliases(alias);
CREATE INDEX idx_pair ON attribute_pair_stats(attr_a, attr_b);
```

### Validation query (runtime)

```sql
SELECT p.id, p.display_name
FROM players p
INNER JOIN player_attributes a
  ON a.player_id = p.id AND a.attribute_id = :row_attr
INNER JOIN player_attributes b
  ON b.player_id = p.id AND b.attribute_id = :col_attr
WHERE p.search_text LIKE :query || '%'
LIMIT 20;
```

---

## Clean & Merge Pipeline (Full Plan)

Execute in order. Each step writes artifacts under `tool/etl/staging/` for debugging.

### Phase D0 — Config lock

**Goal:** Freeze allowlists and name resolution before touching data.

**Deliverables:**

```text
tool/etl/config/clubs_allowlist.yaml      # display_name → club_id
tool/etl/config/nations_allowlist.yaml    # display_name → normalized key
tool/etl/config/leagues_allowlist.yaml    # display_name → competition_id
tool/etl/config/position_map.yaml         # TM position tokens → GK|DEF|MID|FWD
tool/etl/config/name_aliases.yaml       # nation + player spelling overrides
```

**DoD:**

- [x] Every club in the product list maps to exactly one `club_id` in `clubs.csv`.
- [x] All five leagues map to `GB1`, `ES1`, `IT1`, `L1`, `FR1`.
- [x] Nation list includes alias rows for Ivory Coast / USA / etc.

---

### Phase D1 — Raw ingest & sanity checks

**Goal:** Load CSVs with consistent types; fail fast on missing files.

**Steps:**

1. Parse dates as ISO; reject or flag `transfer_date` > today + 365 days (bad scraper rows).
2. Drop rows with null `player_id` / `club_id` where required.
3. Log row counts per file to `tool/etl/reports/ingest_summary.json`.

**DoD:**

- [x] Script exits non-zero if any required CSV is missing.
- [x] Summary JSON lists row counts and date anomaly count.

---

### Phase D2 — Normalize dimensions

**Goal:** Canonical strings for joins.

**Steps:**

| Entity | Rules |
| --- | --- |
| Player name | trim; collapse whitespace; optional ASCII fold for `search_text` |
| Nation | map via `name_aliases.yaml` (e.g. `Cote d'Ivoire` → `ivory_coast`) |
| Club | join only through allowlist `club_id` |
| Competition | upper-case `competition_id`; filter to allowlist + top-5 |

**DoD:**

- [x] No allowlisted club/nation fails lookup.
- [x] Unmapped citizenship values logged to `unmapped_nations.csv` (review quarterly).

---

### Phase D3 — Merge `player_club` stints

**Goal:** Single fact table: player played for club.

**Inputs:** `transfers.csv`, `appearances.csv`.

**Steps:**

1. From **transfers:** emit `(player_id, from_club_id)` and `(player_id, to_club_id)` when club in allowlist.
2. From **appearances:** emit `(player_id, player_club_id)` when club in allowlist.
3. `UNION` → `DISTINCT (player_id, club_id)`.
4. Insert `player_attributes` with `attribute_id = 'club:{club_id}'`, `source` ∈ `transfer` \| `appearance`.

**Optional quality filter:**

- If only one appearance with 0 minutes for a club, still keep (trivia-friendly) OR require `minutes_played > 0` — **product decision: keep all listed stints v1**.

**DoD:**

- [x] Spot-check: Salah has `club:31` (Liverpool); Eto'o has Barcelona + a PL club via appearances/transfers.
- [x] Duplicate `(player_id, club_id)` from multiple sources does not break validation query.

---

### Phase D4 — Derive `player_league`

**Goal:** League attribute edges without implying direct TM player→league field.

**Path A — `league_appearance`:**

- From `appearances.csv`: `(player_id, competition_id)` where `competition_id` ∈ {GB1, ES1, IT1, L1, FR1}.
- `attribute_id = 'league:{competition_id}'`, `source = league_appearance`.

**Path B — `league_club`:**

- Join `player_club` → `clubs.domestic_competition_id` for allowlisted clubs in top-5.
- `attribute_id = 'league:{domestic_competition_id}'`, `source = league_club`.

**Merge:** union both paths (same PK with different `source` allowed).

**DoD:**

- [x] Player with only Segunda appearance does not get `league:ES1` unless Path A or B applies.
- [x] PL club squad member gets `league:GB1` via Path B when club `domestic_competition_id = GB1`.

---

### Phase D5 — `player_nation` from citizenship

**Goal:** Nation attributes for allowlisted countries.

**Steps:**

1. Read `players.country_of_citizenship`; normalize with nation aliases.
2. If normalized nation in allowlist → `attribute_id = 'nation:{key}'`, `source = citizenship`.
3. Insert row in `attributes` if not exists.

**DoD:**

- [x] Drogba → `nation:ivory_coast` (or agreed key) + club edges.
- [x] Dual citizenship: **both** nation edges if TM lists one primary — v1 uses single `country_of_citizenship` only; document limitation.

---

### Phase D6 — `player_position` buckets

**Goal:** Four position attributes per player.

**Steps:**

1. Map `position` + `sub_position` via `position_map.yaml`.
2. One primary bucket per player (prefer `sub_position` when present).
3. `attribute_id = 'pos:GK'` etc., `source = profile`.

**DoD:**

- [x] Goalkeepers never tagged `pos:FWD`.
- [x] ETL report lists count of unmapped position strings.

---

### Phase D7 — Build `players` table (filtered subset)

**Goal:** Keep DB small; only trivia-useful players.

**Include `player_id` when:**

- Count of **distinct** `attribute_id` in `player_attributes` ≥ 2, AND
- At least one edge is club, nation, league, or position (any combination).

**Populate:**

- `display_name` from `players.name`
- `search_text` = normalized name
- `position` / `nation` caches

**DoD:**

- [x] DB player count documented in manifest (expect thousands, not full 47k if filtered).
- [x] No player row with < 2 attributes.

---

### Phase D8 — Aliases & search index

**Goal:** Search UX (“Mo Salah”, “Salah”).

**Steps:**

1. `search_text` on full name.
2. Insert `player_aliases`: surname-only if unique enough; entries from `name_aliases.yaml`.
3. Optional: strip accents (Salah ↔ Mohamed Salah).

**DoD:**

- [x] Prefix search on `salah` returns Mohamed Salah.
- [x] Colliding surnames return multiple rows (acceptable).

---

### Phase D9 — `attribute_pair_stats`

**Goal:** Precompute intersection sizes for all allowlisted attribute pairs that can appear on a board.

**Steps:**

1. For each pair `(attr_a, attr_b)` where types differ (club×nation, league×club, …) **or** both are club or both are league (club×club, league×league for runtime random boards):
   - `player_count = COUNT(DISTINCT player_id)` with both edges.
2. Store `sample_player_ids` (top N by appearance count or market value if available).

**Thresholds:**

| `player_count` | Board use |
| --- | --- |
| 0 | **Forbidden** on generated boards |
| 1–2 | **Risky** — manual QA only |
| ≥ 3 | OK for casual play |
| ≥ 10 | Ideal |

**DoD:**

- [x] `attribute_pair_stats` covers all pairs used in `boards` with `player_count ≥ 3`.
- [x] Report `forbidden_pairs.json` (count = 0) for QA.

---

### Phase D10 — Board generation & curation

**Goal:** No impossible 3×3 layouts.

**Board shape:**

- 3 **row** headers + 3 **col** headers (6 distinct `attribute_id`s per board).
- Cell `(r,c)` validates against `row[r]` AND `col[c]`.

**Generation algorithm:**

1. Choose attribute type mix (recommended v1: **row = clubs, col = nations** OR **row = leagues, col = clubs** — configurable template).
2. Pick 6 attributes from allowlists.
3. For all 9 pairs `(row[i], col[j])`, require `player_count ≥ MIN_INTERSECTION` (default 3).
4. `min_intersection` on board = minimum of the nine counts.
5. Store in `boards` + `board_slots`.

**Curation:**

- Hand-pick 20–50 “featured” boards (famous intersections).
- Auto-generate pool of 100+ valid boards; tag difficulty by `min_intersection`.

**DoD:**

- [x] Zero boards in DB with any cell `player_count < MIN_INTERSECTION`.
- [x] At least 20 playable boards shipped in v1 asset.

---

### Phase D7b — Player image URLs (schema v2)

**Goal:** Resolve optional Commons thumbnail URLs for players (display-only; not required for validation).

**Steps:**

1. Run after D7: `python tool/etl/fetch_player_images.py` (full) or `--only-missing` (incremental).
2. Output: `tool/etl/staging/player_images.csv` (`player_id`, `image_url`, `commons_file`).
3. D11 merges into `players.image_url`; players without a row keep `NULL`.

**DoD:**

- [x] Script implemented (Phase P2 in [player-image-plan.md](./player-image-plan.md)).
- [x] Shipped in schema v2 DB — 11,867 / 28,221 players with `image_url` (2026-06-09); missing CSV → all `image_url` NULL.

---

### Phase D11 — SQLite export & manifest

**Goal:** Produce Flutter asset.

**Steps:**

1. Write `tool/etl/output/tiki_taka.db` with WAL disabled; vacuum.
2. Write `manifest.json`:

    ```json
    {
      "schema_version": 1,
      "built_at": "ISO-8601",
      "source_csv_hash": "sha256:…",
      "player_count": 0,
      "attribute_count": 0,
      "board_count": 0
    }
    ```

3. Copy to `assets/db/tiki_taka.db` and register in `pubspec.yaml`.

**DoD:**

- [x] DB opens read-only in Flutter smoke test.
- [x] File size target: **< 20 MB** for v1 (adjust after first build).

---

### Legendary player supplements (post-D6)

**Goal:** Add curated legends (Maradona, Pelé, Di Stéfano, etc.) missing from Transfermarkt exports.

**Pipeline** (runs after D6, before D7 in `tool/etl/run_pipeline.ps1`):

```text
legendary-players/ingest_legendary_players.py
  → staging/legendary/*.csv
merge_legendary_supplements.py
  → merged into player build
build_players.py (profile fallback from legendary_player_profiles.csv)
search_rank.py + legendary_search_rank_boost.yaml
fetch_player_images.py (Wikidata QID fast path for legends)
build_database.py → schema v3
```

**Additional `player_attributes.source` values:** `legendary_career`, `legendary_citizenship`, `legendary_profile`, `league_club`.

**Detailed runbook:** [legendary-players/legendary_players_plan.md](../legendary-players/legendary_players_plan.md)

**Shipped stats (2026-06-20):** schema v3, 28,454 players, 12,118 with images, ~20.2 MB — see `tool/etl/output/manifest.json`.

**Flutter regression:** `flutter test test/features/tiki_taka/data/legendary_players_smoke_test.dart`

---

### Phase D12 — QA & regression pack

**Goal:** Frozen tests on data, not only code.

**Deliverables:**

```text
tool/etl/fixtures/validation_cases.yaml
tool/etl/run_validation_cases.py
```

Example cases:

| Player | Row attr | Col attr | Expected |
| --- | --- | --- | --- |
| Mohamed Salah | nation:egypt | club:31 | valid |
| Jude Bellingham | club:dortmund | league:GB1 | valid (if edges exist) |
| Random invalid | club:31 | club:31 | invalid (same attr) or N/A |

**DoD:**

- [x] ETL test script runs cases; CI optional.
- [x] Re-run after each monthly CSV refresh.

---

## What NOT to merge in v1

| Source | Reason |
| --- | --- |
| `player_valuations.csv` | Not needed for validation |
| `game_events.csv` | Scope creep |
| `club_games.csv` | Redundant with appearances |
| TM `image_url` | Do not ship (use Wikidata → Commons via D7b instead) |
| Full `appearances` in SQLite | Derive edges only |

---

## Monthly Refresh Workflow

```text
1. Replace transfermarkt-datasets/*.csv
2. python tool/etl/ingest_legendary_players.py && merge_legendary_supplements.py   # legendary supplements
3. python tool/etl/build_players.py          # if player set changed
4. python tool/etl/fetch_player_images.py --only-missing   # new player images (see player-image-plan.md)
5. python tool/etl/build_database.py
6. Review tool/etl/reports/ (unmapped nations, forbidden pairs, row deltas, image summary)
7. Bump meta.schema_version if schema changed
8. Copy tiki_taka.db → assets/db/
9. `python tool/etl/run_validation_cases.py` (also runs at end of `build_database.py`)
10. `flutter test test/features/tiki_taka/data/legendary_players_smoke_test.dart`
11. `flutter test test/features/tiki_taka/release/tiki_taka_database_smoke_test.dart`
```

If `player_count` for a live board drops below threshold, retire `board_id` or regenerate boards.

---

## Flutter Connection (when mode is implemented)

```text
lib/features/tiki_taka/
├── data/local/tiki_taka_database.dart
├── data/local/daos/validation_dao.dart
├── data/local/daos/player_search_dao.dart
├── data/local/daos/board_dao.dart
├── domain/logic/tiki_taka_game_engine.dart
└── domain/services/answer_validator.dart
```

| Layer | Responsibility |
| --- | --- |
| SQLite | Attributes, edges, boards, search |
| `AnswerValidator` | Calls DAO; returns valid / invalid + player id |
| `TikiTakaGameEngine` | Turn, cell claim, used players, win via shared `WinChecker` |
| UI | Renders 3×3 + 6 headers; search sheet on cell tap |

---

## Future: Coach attributes (Phase D+)

**Inputs:** `games.csv` (`home_club_manager_name`, `away_club_manager_name`), `game_lineups.csv`.

**Merge:**

1. Join lineup `(game_id, player_id, club_id)` to game.
2. If `club_id == home_club_id` → manager = `home_club_manager_name`; else away.
3. Normalize manager name (YAML aliases for Pep, Sir Alex, …).
4. `attribute_id = 'coach:{slug}'`, `source = coach_match`.

Same `player_attributes` table; validation query unchanged.

---

## Implementation Sequence Summary

| Phase | Output |
| --- | --- |
| D0 | YAML allowlists |
| D1 | Ingest report |
| D2 | Normalized staging tables |
| D3 | Club edges |
| D4 | League edges |
| D5 | Nation edges |
| D6 | Position edges |
| D7 | `players` subset |
| D7b | `player_images.csv` (optional; schema v2) |
| D8 | Aliases |
| D9 | `attribute_pair_stats` |
| D10 | `boards` |
| D11 | `tiki_taka.db` + manifest |
| D12 | QA fixtures |

**Do not start Flutter Tiki-Taka UI until D11 passes D12 spot-checks** (or ship with a minimal 5-board DB for prototyping only).

---

## Resolved Product Decisions (v1)

All gameplay decisions that blocked ETL board curation (D10) and Flutter implementation are **locked**.

**Source of truth:** [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md) — Section 30 (Resolved Product Decisions) and Appendix A (v1 Rules Checklist).

| Decision | v1 answer |
| --- | --- |
| Nation rule | Citizenship from player profile (`country_of_citizenship`) |
| Failed answer (1P) | Remove one heart; cell stays empty |
| Reuse player | Banned — same `player_id` once per board |
| Default board template | Clubs × Nations |
| `MIN_INTERSECTION` | 3 (medium default) |
| Data source | Bundled `tiki_taka.db` only |
| Coach attributes | Deferred post-v1 |
| Local multiplayer | Deferred post-v1 |

Post-v1 topics (national-team caps, dual citizenship, multiplayer steal rules, AI, coach ETL) are documented in the rules doc **Post-v1** table and [dataset-plan2.md](./dataset-plan2.md) — Future Phases.

---

## Related paths

| Path | Role |
| --- | --- |
| `transfermarkt-datasets/` | Raw CSV input (gitignored recommended) |
| `tool/etl/` | Build scripts (to be created) |
| `assets/db/tiki_taka.db` | Shipped database |
| `docs/dataset-plan.md` | This file |
| `docs/tiki-taka-toe-rules.md` | Gameplay rules specification |

---

*Last updated: 2026-06-06 — open product decisions resolved; points to tiki-taka-toe-rules Section 30.*
