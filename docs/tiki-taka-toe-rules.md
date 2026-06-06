# Tiki-Taka-Toe — Gameplay Rules Specification

## Overview

## What is Tiki-Taka-Toe?

**Tiki-Taka-Toe** is a football knowledge strategy mode played on a 3×3 Tic Tac Toe board.

The player earns cells by guessing footballers who match two football-related attributes.

The game combines:

* Football knowledge
* Quick recall
* Board control
* Classic Tic Tac Toe win logic
* Completion-based challenge

The first version of this mode is a **1 Player Mode with no AI**.

Multiplayer will be added later as a future mode.

---

## 1. Mode Priority

### Current Priority

The first version to build is:

```text
Tiki-Taka-Toe — 1 Player Mode
```

This mode contains:

* One user only
* No AI opponent
* No player turn switching
* No player turn indicator
* No move counter displayed
* Timer
* 5 hearts
* Search-and-select player guessing
* Win by aligning 3 correct cells
* Optional continue after first win
* Full-board completion challenge

---

### Future Mode

The following mode is planned for later and is NOT a priority now:

```text
Tiki-Taka-Toe — Local Multiplayer
```

Multiplayer rules should be documented separately or added later after the 1 Player Mode is completed.

---

## 2. Board Structure

The board uses a 3×3 playable grid.

In addition to the 9 playable cells, the screen displays:

* 3 column attributes above the board
* 3 row attributes on the left side of the board

Each playable cell represents the intersection between:

```text
Row Attribute
AND
Column Attribute
```

Example:

```text
Liverpool × Egypt
```

Valid answer:

```text
Mohamed Salah
```

---

## 3. Attribute Types

The mode supports the following attribute categories:

### Clubs

Examples:

* Real Madrid
* Barcelona
* Liverpool
* Chelsea
* Bayern Munich

**v1 scope:** 56 allowlisted clubs (see [dataset-plan.md](./dataset-plan.md) — Clubs allowlist). ETL only emits clubs in this list.

---

### Leagues

Examples:

* Premier League
* La Liga
* Serie A
* Bundesliga
* Ligue 1

**v1 scope:** Top-5 European leagues only (`GB1`, `ES1`, `IT1`, `L1`, `FR1`). League edges are derived from appearances and club domestic competition — not from live API queries.

---

### Nations

Examples:

* Egypt
* Brazil
* Argentina
* France
* Portugal

**v1 scope:** 25 allowlisted nations. **Nation rule (v1):** citizenship from player profile (`country_of_citizenship`), normalized via ETL aliases. National-team caps are optional for v1.1.

---

### Player Positions

Supported simplified positions:

* Goalkeeper
* Defender
* Midfielder
* Forward

Transfermarkt sub-positions are mapped into these four buckets at build time.

---

### Coaches (deferred)

Coach attributes (e.g. Pep Guardiola, Carlo Ancelotti) are planned but **not in v1 SQLite**. Schema reserves them for a future ETL phase.

---

## 4. Attribute Matching Logic

A player is valid for a cell when the player is linked to BOTH attributes independently.

The relationship does not need to happen at the same time.

Example:

```text
Premier League × Barcelona
```

Samuel Eto'o is valid if:

```text
Samuel Eto'o linked to Barcelona
AND
Samuel Eto'o linked to Premier League
```

The game does NOT ask:

```text
Did the player play for Barcelona while in the Premier League?
```

Only independent attribute matching is required.

This is the same **data contract** documented in [dataset-plan.md](./dataset-plan.md):

```text
valid(player, attr_row, attr_col) ⇔
  player linked to attr_row   (independently)
  AND player linked to attr_col (independently)
```

---

## 5. 1 Player Mode Rules

### Objective

The user must fill cells by guessing valid footballers.

The user wins the first objective by completing:

* 3 horizontal cells
* 3 vertical cells
* 3 diagonal cells

After the first win, the user may continue playing on the same board to complete all 9 cells.

---

### Player State

The 1 Player Mode contains:

```text
hearts: 5
timer: active
board: 9 cells
selected players: stored per cell
game status: ongoing / firstWin / completed / lost
```

---

### No Turn System

Because this is a 1 Player Mode:

* No player turn indicator is displayed
* No X/O active player state is needed
* No opponent exists
* No AI exists
* No move counter is displayed

---

## 6. Hearts System

The user starts with:

```text
5 hearts
```

A heart is lost when the user selects an invalid player for a cell.

Invalid guesses include:

* Player does not match both cell attributes
* Player does not exist in the database
* Player has already been used, if duplicate answers are disabled
* User confirms an invalid selection

When hearts reach:

```text
0
```

The user loses the game.

---

## 7. Timer System

The mode includes a timer.

The timer should start when the board becomes playable.

The timer should stop when:

* User loses
* User completes the full board
* User exits the match

When the user achieves the first 3-in-a-row win, the timer behavior can follow one of two options:

### Recommended Option

Continue timer if the user chooses:

```text
Continue Playing
```

Stop timer only when the user chooses:

```text
Restart
```

or

```text
Go Home
```

This supports full-board completion as a challenge.

---

## 8. Cell Interaction Flow

### Step 1 — User taps an empty cell

When the user taps a playable empty cell:

```text
Open player search dialog
```

---

### Step 2 — Search dialog appears

The dialog contains:

* Cell attributes
* Search input
* Player results list
* Cancel button

Example dialog context:

```text
Liverpool × Egypt
Search player...
```

---

### Step 3 — User types player name

As the user types, a list of matching players is displayed.

The search should support:

* Full names
* Common names
* Aliases
* Accent-insensitive search

Examples:

```text
Cristiano Ronaldo
Ronaldo
CR7

Lionel Messi
Messi

Kylian Mbappé
Mbappe
```

Search runs against the local `players` table and `player_aliases` (prefix match on normalized `search_text` / alias). See [dataset-plan.md](./dataset-plan.md) — Phase D8.

---

### Step 4 — User selects a player

After the user selects a player:

```text
Validate selected player against row attribute + column attribute
```

---

### Step 5 — Valid answer

If the selected player is valid:

* The cell becomes filled
* The player name is written inside the cell
* The cell becomes locked
* Win checker runs
* Completion checker runs

---

### Step 6 — Invalid answer

If the selected player is invalid:

* One heart is removed
* The cell remains empty
* The player name is not placed
* User may try another cell or same cell again

If hearts reach 0:

```text
Show lose dialog
```

---

## 9. Cell Display Rules

When a valid player is selected, the player name is displayed inside the cell.

The text should:

* Fit inside the cell
* Adapt its size to the available space
* Be shown diagonally
* Keep the cell size fixed
* Never resize the board cell

Important:

```text
Text adapts to the cell.
The cell does not adapt to the text.
```

Recommended visual behavior:

* Short names use larger text
* Long names use smaller text
* Text can wrap if needed
* Text remains readable
* Text should not overflow outside the cell

---

## 10. Occupied Cell Rules

Once a cell has a valid player:

* The cell is locked
* The player name remains visible
* The cell cannot be selected again
* The answer cannot be changed unless a future edit feature is added

For the first version:

```text
No editing filled cells
```

---

## 11. Duplicate Player Rule

**Product decision (v1):** duplicate answers are **disabled**.

```text
A player can only be used once per board.
```

Example:

If the user already used:

```text
Lionel Messi
```

then Messi cannot be used again in another cell.

This prevents one famous player from solving multiple cells and makes the board more strategic.

Selecting an already-used player counts as an invalid guess and removes one heart.

Used player IDs are tracked in memory by the game engine/cubit — not in SQLite.

---

## 12. Win Checker

The mode uses the same classic Tic Tac Toe win checker.

A win occurs when the user has filled 3 cells in a row:

* Horizontally
* Vertically
* Diagonally

Examples:

```text
Top row complete
Middle row complete
Bottom row complete
Left column complete
Middle column complete
Right column complete
Main diagonal complete
Anti-diagonal complete
```

---

## 13. First Win State

When the user completes the first 3-in-a-row:

```text
Show win dialog
```

The win dialog should include:

* Win message
* Time
* Remaining hearts
* Restart option
* Go Home option
* Continue Playing option

---

### Continue Playing

If the user selects:

```text
Continue Playing
```

then:

* The same board attributes remain
* The already-filled cells remain
* The game continues
* The user can keep filling empty cells
* Hearts remain the same
* Timer continues

The goal after continuing is:

```text
Full board completion
```

---

## 14. Full Board Completion

Full board completion happens when:

```text
All 9 cells are filled with valid players
```

When this happens:

```text
Show completion win dialog
```

The completion dialog should include:

* Completion message
* Final time
* Remaining hearts
* Restart option
* Go Home option

The completion dialog should NOT include:

```text
Continue Playing
```

because the board is already complete.

---

## 15. Lose State

The user loses when:

```text
hearts = 0
```

When the user loses:

* Stop gameplay
* Disable board interaction
* Stop timer
* Show lose dialog

Lose dialog options:

* Restart
* Go Home

Optional:

* Show correct possible answers for missed cells later
* Show board summary later

---

## 16. Draw State

There is no draw state in 1 Player Mode.

The game ends only by:

* Losing all hearts
* Completing first win
* Completing full board
* Restarting
* Exiting

---

## 17. Board Generation Rules

The game must avoid impossible boards.

A board is valid only if every playable cell has at least one valid answer.

For each intersection:

```text
rowAttribute × columnAttribute
```

the database must contain at least:

```text
1 valid player
```

Boards are **pre-generated at build time** and stored in the `boards` + `board_slots` tables. At runtime the app loads a curated board — it does not generate random attribute combinations on the device.

### Recommended board templates (v1)

| Template | Row headers | Column headers |
| --- | --- | --- |
| **Default (recommended)** | Clubs | Nations |
| Alternate | Leagues | Clubs |

Mixed-type rows/columns are allowed if every cell passes the intersection threshold.

---

### Recommended Difficulty Rules

Difficulty maps to the **minimum** `player_count` across all 9 cells on a board (`min_intersection` in SQLite).

#### Easy

Each cell should have at least:

```text
5 valid players
```

(`min_intersection ≥ 5`)

---

#### Medium

Each cell should have at least:

```text
3 valid players
```

(`min_intersection ≥ 3`) — **default ETL threshold** for shipped boards.

---

#### Hard

Each cell should have at least:

```text
1 valid player
```

(`min_intersection ≥ 1`) — manual QA only; pairs with count 1–2 are flagged **risky** in ETL reports.

---

### ETL quality thresholds (build-time)

These align with [dataset-plan.md](./dataset-plan.md) — Phase D9:

| `player_count` | Board use |
| --- | --- |
| 0 | **Forbidden** — board rejected |
| 1–2 | **Risky** — manual QA only |
| ≥ 3 | OK for casual / medium play |
| ≥ 5 | Easy mode |
| ≥ 10 | Ideal |

---

### Board Rejection Rules

Reject a generated board if:

* Any cell has 0 valid players
* Too many cells have only 1 obscure answer (below chosen `MIN_INTERSECTION`)
* The board repeats the same attribute on row and column
* The board feels unfair
* The board contains unsupported combinations (attributes outside v1 allowlists)

---

## 18. Data Validation Rules

A player is valid for a cell if:

```text
player has rowAttribute
AND
player has columnAttribute
```

Example:

```text
Egypt × Liverpool
```

Mohamed Salah:

```text
Egypt ✓
Liverpool ✓
```

Result:

```text
Valid
```

Example:

```text
Italy × Real Madrid
```

Fabio Cannavaro:

```text
Italy ✓
Real Madrid ✓
```

Result:

```text
Valid
```

Example:

```text
Real Madrid × Italy
```

Cristiano Ronaldo:

```text
Real Madrid ✓
Italy ✗
```

Result:

```text
Invalid
```

---

## 19. Data Source Strategy

The game uses a **local SQLite database** bundled with the app. Raw CSV files and network APIs are **never** queried during gameplay.

### Build-time pipeline

Source data is the [transfermarkt-datasets](https://github.com/dcaribou/transfermarkt-datasets) compilation (CC0). CSV files live in `transfermarkt-datasets/` on the developer machine and are **not shipped** in the app bundle.

```text
transfermarkt-datasets/*.csv     (build-time input only)
↓
tool/etl/config/*.yaml           (allowlists, aliases, position map)
↓
tool/etl/build_database.py       (clean → merge → sqlite)
↓
tool/etl/output/tiki_taka.db
tool/etl/output/manifest.json
↓ copy
assets/db/tiki_taka.db           (Flutter read-only asset)
↓
Runtime: TikiTakaDatabase        (search, validate, load board)
```

Full ETL phases, merge rules, and schema are defined in [dataset-plan.md](./dataset-plan.md).

### Runtime rules

* Open `assets/db/tiki_taka.db` **read-only** at app start or first Tiki-Taka session.
* Validate answers with SQL joins on `player_attributes` (independent AND rule).
* Search players via `players.search_text` and `player_aliases`.
* Load board layout from `boards` + `board_slots`.
* Match state (hearts, timer, filled cells, used player IDs) lives **in memory** in the game engine/cubit — not in SQLite.

### Why not live APIs (including Wikidata)

| Reason | Detail |
| --- | --- |
| Speed | Local joins are instant; no network latency |
| Offline | Mode works without connectivity |
| Reliability | No rate limits, timeouts, or inconsistent live results |
| Control | ETL allowlists, aliases, and dedupe produce predictable trivia |
| Board QA | `attribute_pair_stats` precomputes intersection counts before ship |

Wikidata or other live sources may inform future data enrichment, but **v1 gameplay reads only the bundled SQLite asset** produced by the Transfermarkt ETL.

### Refresh cadence

Re-run the ETL monthly (or when source CSVs update), bump `meta.schema_version` if needed, copy the new DB to `assets/db/`, and run validation fixtures. See [dataset-plan.md](./dataset-plan.md) — Monthly Refresh Workflow.

### Licensing note

Use derived football facts only. Do **not** ship Transfermarkt `image_url` values or hotlink TM assets in UI.

---

## 20. Local Database Content

The shippable database file is `tiki_taka.db`. Schema version is stored in the `meta` table.

### Core tables (v1)

| Table | Purpose |
| --- | --- |
| `meta` | `schema_version`, `built_at`, source hash |
| `attributes` | Board headers — clubs, nations, leagues, positions (`club:31`, `nation:egypt`, `league:GB1`, `pos:FWD`) |
| `players` | Filtered player subset with `display_name`, `search_text`, position/nation cache |
| `player_attributes` | Independent player ↔ attribute edges (provenance via `source` column) |
| `player_aliases` | Alternate search strings (surnames, nicknames, manual overrides) |
| `attribute_pair_stats` | Precomputed intersection counts for board viability |
| `boards` | Curated board metadata including `min_intersection` |
| `board_slots` | Row/column attribute assignments per board |

### Edge provenance (`player_attributes.source`)

| `source` | Meaning |
| --- | --- |
| `transfer` | Club stint from `transfers.csv` |
| `appearance` | Club from `appearances.csv` |
| `citizenship` | Nation from player profile |
| `league_appearance` | Top-5 league from appearance competition |
| `league_club` | Top-5 league derived from club domestic competition |
| `profile` | Position bucket from player profile |

### Not in v1 SQLite

* Coach edges (`coach:*`) — deferred
* Raw CSV rows — derive edges only
* Transfermarkt image URLs
* Full appearance history

Optional dev-only table (not required for gameplay):

```text
attribute_pair_players   # full player list per pair — QA/debug only
```

---

## 21. Attribute Pair Precheck

To avoid impossible boards, the ETL precomputes intersection sizes in `attribute_pair_stats`.

Example:

```text
Liverpool × Egypt = 1 valid player
Barcelona × Argentina = many valid players
Chelsea × Goalkeeper = several valid players
```

Each row stores `attr_a`, `attr_b`, `player_count`, and optional `sample_player_ids` for QA.

The board generator uses this table to:

1. Reject any pair with `player_count = 0`
2. Enforce difficulty via minimum count across all 9 cells
3. Tag boards with `min_intersection` for difficulty selection in the app

At runtime the app may read `attribute_pair_stats` for hints or debug UI, but **validation always re-checks** the selected player against `player_attributes` — precomputed counts are for generation and QA, not a substitute for per-guess validation.

---

## 22. UI Rules for 1 Player Mode

The gameplay screen should show:

* 3 column attributes above the board
* 3 row attributes on the left
* 9 playable cells
* Timer
* Hearts
* Pause / exit button
* Restart button if needed

The gameplay screen should NOT show:

* Player turn indicator
* X/O turn text
* Move counter
* Opponent panel
* AI panel

---

## 23. Dialog Rules

### Player Search Dialog

The dialog appears after tapping an empty cell.

It should include:

* Selected cell attributes
* Search input
* Search results
* Player name
* Optional player image (app assets only — not TM hotlinks)
* Optional player nationality/club hints
* Cancel button

The user must select a player from the list.

For the first version:

```text
Do not allow free-text confirmation without selecting a database player.
```

This prevents spelling issues and improves validation accuracy.

---

## 24. Game Statuses

Recommended statuses:

```text
initial
loadingBoard
ongoing
firstWin
continuing
completed
lost
```

---

## 25. Turn / Move Lifecycle

Although there is no turn system, each guess follows a deterministic lifecycle:

```text
User taps empty cell
↓
Open search dialog
↓
User searches player
↓
User selects player
↓
Validate player (DAO → player_attributes AND check + duplicate check)
↓
If valid: fill cell
↓
If invalid: remove heart
↓
Check hearts
↓
Check win
↓
Check full board completion
↓
Continue gameplay or show dialog
```

---

## 26. Edge Cases

The implementation must handle:

* Empty search results
* Player selected for wrong cell
* Player already used
* User closes dialog
* Rapid tapping multiple cells
* User taps occupied cell
* Invalid guess with 1 heart remaining
* First win and full board completion happening close together
* Restart while dialog is open
* App backgrounding while timer is running
* Board generation failure (fallback board or error state)
* Long player names
* Similar player names
* Accented names (normalized at ETL; search is accent-insensitive)

---

## 27. Testing Requirements

### Board Generation Tests

Verify:

* No impossible boards are generated
* Every cell has at least the required number of valid answers
* Difficulty rules are respected
* Rejected boards regenerate correctly

Use ETL fixtures: `tool/etl/fixtures/validation_cases.yaml` and `tool/etl/run_validation_cases.py` (see [dataset-plan.md](./dataset-plan.md) — Phase D12).

---

### Validation Tests

Verify:

* Valid player passes
* Invalid player fails
* Duplicate player fails (duplicates disabled in v1)
* Club + nation combinations work
* League + club combinations work
* Position + club combinations work
* Position + nation combinations work

---

### Game Flow Tests

Verify:

* Valid guess fills cell
* Invalid guess removes heart
* Hearts reaching 0 triggers lose state
* Timer starts correctly
* Timer stops correctly
* First 3-in-a-row triggers win dialog
* Continue Playing keeps board state
* Full board completion triggers completion dialog
* Restart resets all state

---

### UI Tests

Verify:

* No player turn indicator appears
* No move counter appears
* Hearts are visible
* Timer is visible
* Player name fits inside cell
* Long names do not break layout
* Occupied cells cannot be selected again

---

## 28. Future Multiplayer Mode

The future multiplayer mode will use the same:

* Board structure
* Attribute system
* Player validation engine
* Win checker

But it will add:

* Player X
* Player O
* Turn switching
* Steal mechanic
* Simultaneous name reveal
* Square ownership by X/O marks

Multiplayer is NOT part of the first implementation priority.

**Open product note (multiplayer only):** on a failed answer, decide whether the cell stays empty and turn passes vs opponent claims the cell — irrelevant to 1 Player Mode, where failed answers only cost a heart.

---

## 29. Final Design Philosophy

Tiki-Taka-Toe 1 Player Mode is a football knowledge board challenge.

The mode should feel:

* Fast
* Clean
* Strategic
* Replayable
* Fair
* Knowledge-based

The user is not fighting an AI.

The user is fighting:

* The board
* The timer
* The heart limit
* Their own football memory

Every correct player earns control.

Every wrong guess costs a heart.

The first line wins.

The full board proves mastery.

---

## 30. Resolved Product Decisions (v1)

| Decision | Answer |
| --- | --- |
| Nation rule | Citizenship from player profile (v1); national-team caps deferred |
| Failed answer (1P) | Remove one heart; cell stays empty; user retries freely |
| Reuse player | **Banned** — same `player_id` once per board |
| Default board template | **Clubs × Nations** (alternate: Leagues × Clubs) |
| Default `MIN_INTERSECTION` | **3** (medium); easy = 5, hard = 1 with manual QA |
| Data source | Transfermarkt CSV → ETL → `tiki_taka.db` (not live Wikidata) |
| Coach attributes | Deferred post-v1 |

---

### Related docs

| Doc | Role |
| --- | --- |
| [dataset-plan.md](./dataset-plan.md) | ETL pipeline, SQLite schema, allowlists, board curation |
| [rules.md](./rules.md) | Mode comparison across the app |
| [classic-rules.md](./classic-rules.md) | Classic Tic Tac Toe rules (shared win checker concept) |

---

*Last updated: 2026-06-06 — initial gameplay rules; data source aligned with dataset-plan.*
