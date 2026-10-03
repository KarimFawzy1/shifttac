# Egyptian Premier League — database ingest plan

**Goal:** Ship qualifying Egyptian league players into `assets/db/tiki_taka.db` with popularity-based search ranking and Wikidata images (when QIDs are resolved).

## Source files

| File | Role |
| --- | --- |
| `Top Egyptian Premier League Players.csv` | Master bios (name, nation, DOB, position, clubs) |
| `egyptian_league_players_popularity_ranked.csv` | Popularity rank/score/tier overlay |
| **`egyptian_players_combined.csv`** | **Merged, deduplicated output (787 players)** |
| `egyptian_players_with_tm_id.csv` | Combined + resolved `transfermarkt_id` + `wikidata_qid` (after Phase 0) |

## Phase 0 — CSV prep (done / next steps)

### 0a. Merge sources ✅

```powershell
python egyptian-players/merge_egyptian_sources.py
```

- Joins popularity data by player name (handles BOM in ranked CSV).
- Merges alias duplicates (Bencharki → Achraf Bencharki, Aboul Gabal → Abou Gabal).
- Keeps same-name different people separate (e.g. two `Ahmed Magdy` rows merged only when profiles identical).
- **787 unique players** from 796 master rows (9 duplicates removed).

### 0b. Gap analysis ✅

```powershell
python egyptian-players/gap_analysis.py
```

Reports: `egyptian-players/reports/gap_clubs.json`, `gap_nations.json`

### 0c. Resolve Transfermarkt + Wikidata IDs (required before DB ingest)

```powershell
python egyptian-players/resolve_transfermarkt_ids.py
```

Uses Wikidata SPARQL (DOB + nationality scoring). Players without DOB go to `egyptian_players_manual_review.csv`.

### 0d. Generate popularity search boosts (after TM IDs)

```powershell
python egyptian-players/generate_search_rank_boost.py
```

Writes `tool/etl/config/egyptian_search_rank_boost.yaml` (score × 1.2M EUR-equivalent).

## Data quality snapshot

| Metric | Count |
| --- | ---: |
| Combined players | 787 |
| Missing DOB (`TBD` / placeholder) | 401 |
| Missing `wikidata_qid` | 787 (all — images need Phase 0c) |
| Missing popularity score | 0 |

## Clubs added to project

**22 Egyptian Premier League clubs** added to `tool/etl/config/clubs_allowlist.yaml` with Transfermarkt IDs:

| Club | TM ID |
| --- | ---: |
| Al Ahly | 7 |
| Zamalek | 664 |
| Pyramids | 44664 |
| Al Masry | 9094 |
| Smouha | 23387 |
| ENPPI | 9218 |
| Ismaily | 3595 |
| Ceramica Cleopatra (Cleopatra FC) | 57439 |
| Wadi Degla | 18234 |
| El Gouna | 20572 |
| Haras El Hodoud | 12093 |
| Petrojet | 10957 |
| Pharco | 47058 |
| Al Ittihad Alexandria | 3963 |
| Al Mokawloon | 3369 |
| Misr Lel Makkasa | 22702 |
| Modern Sport | 68770 |
| National Bank (Bank El Ahly) | 62448 |
| ZED | 47010 |
| Tala'ea El Gaish | 13444 |
| Ghazl El Mahalla | 13446 |

**Still missing from allowlist** (~448 unique club strings): mostly foreign stints (Raja Casablanca, PAOK, Derby County) and lower Egyptian sides (Aswan, El Dakhleya, El Entag El Harby, Olympic Club, Tersana, etc.). See `reports/gap_clubs.json` for the full list.

**Club aliases:** `tool/etl/config/egyptian_club_aliases.yaml` normalizes spelling variants (Al-Masry → Al Masry, Bank El Ahly → National Bank, etc.).

**Asset TODO:** Add PNG crests under `assets/tiki_taka/attrs/clubs/` for new Egyptian clubs (`club_7.png`, `club_664.png`, …).

## Nations added to project

**29 nationalities** added to `tool/etl/config/nations_allowlist.yaml`:

Tunisia, Angola, Burkina Faso, Mali, Palestine, Guinea, DR Congo, Zambia, Ethiopia, Uganda, Benin, Chad, Eritrea, French Guiana, Gabon, Gambia, Jamaica, Jordan, Kenya, Malawi, Mauritania, Mozambique, Namibia, Rwanda, Slovenia, South Africa, Sudan, Syria, Togo

**Normalization** in `tool/etl/config/name_aliases.yaml`: Congolese → DR Congo, Morocca → Morocco, Gabonese → Gabon, etc.

**Asset TODO:** Add SVG flags under `assets/tiki_taka/attrs/nations/` for each new slug.

**Policy note:** Zambia and South Africa are in `STRIPPED_NATIONS` for legendary ingest — decide whether Egyptian players from these nations should be included (currently they resolve but may be stripped at ingest).

## Phase 1–2 — ETL integration

Egyptian players use the **same supplement path as legends**:

1. `tool/etl/ingest_legendary_players.py` — reads both `legendary_players_with_tm_id.csv` and `egyptian_players_with_tm_id.csv`
2. `tool/etl/merge_legendary_supplements.py` — merges into TM staging
3. `tool/etl/build_players.py` — applies `egyptian_search_rank_boost.yaml`
4. `tool/etl/fetch_player_images.py` — uses resolved `wikidata_qid`
5. `tool/etl/build_database.py` → `assets/db/tiki_taka.db`

```powershell
tool/etl/run_pipeline.ps1
```

## Player inclusion gate (unchanged)

Each player needs ≥2 distinct attributes (club, nation, league, or position). Egyptian players with only Egypt nationality and no allowlisted club are **excluded**.

## Known CSV data issues

- `Saleh Selim` — club field contains `Hussein Hegazi` (player name, not a club)
- Historic players may rank low in popularity despite fame (heuristic weighting)
- `01/01/YYYY` placeholder DOBs treated as missing for Wikidata matching
