import csv
import sqlite3
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rows = list(
    csv.DictReader(
        (ROOT / "legendary-players/legendary_players_with_tm_id.csv").open(
            encoding="utf-8"
        )
    )
)

conn = sqlite3.connect(ROOT / "assets/db/tiki_taka.db")
in_db = []
for r in rows:
    tm = (r.get("transfermarkt_id") or "").strip()
    if not tm:
        continue
    pid = f"tm:{tm}"
    if conn.execute("SELECT 1 FROM players WHERE id=?", (pid,)).fetchone():
        in_db.append(r["Player Name"])

norm = ROOT / "tool/etl/staging/normalized/players.csv"
legend_tm = {(r.get("transfermarkt_id") or "").strip() for r in rows if r.get("transfermarkt_id")}
overlap = set()
if norm.exists():
    tm_ids = {r["player_id"] for r in csv.DictReader(norm.open(encoding="utf-8"))}
    overlap = legend_tm & tm_ids

missing_tm_id = [r for r in rows if not (r.get("transfermarkt_id") or "").strip()]
missing_wikidata = [r for r in rows if not (r.get("wikidata_qid") or "").strip()]
empty_nat = [r["Player Name"] for r in rows if not (r.get("Nationality") or "").strip()]
empty_clubs = [r["Player Name"] for r in rows if not (r.get("Senior Clubs Played For") or "").strip()]

print("total_players", len(rows))
print("with_transfermarkt_id", len(legend_tm))
print("with_wikidata_qid", len(rows) - len(missing_wikidata))
print("already_in_shipped_db", len(in_db), in_db[:10])
print("in_normalized_tm_players", len(overlap))
print("not_in_tm_dataset", len(legend_tm - overlap) if overlap else "n/a")
print("missing_tm_id_count", len(missing_tm_id))
print("missing_wikidata_count", len(missing_wikidata))
print("empty_nationality_after_filter", len(empty_nat), empty_nat[:5])
print("empty_clubs_after_filter", len(empty_clubs), empty_clubs[:5])

positions = Counter((r.get("Position") or "").strip() for r in rows)
print("positions", dict(positions))
