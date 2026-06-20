import csv
import sqlite3
from collections import Counter
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
rows = list(csv.DictReader((ROOT / "legendary-players/legendary_players_with_tm_id.csv").open(encoding="utf-8")))
conn = sqlite3.connect(ROOT / "assets/db/tiki_taka.db")
cur = conn.cursor()

in_db, not_in_db = [], []
for r in rows:
    pid = f"tm:{r['transfermarkt_id'].strip()}"
    cur.execute("SELECT display_name FROM players WHERE id=?", (pid,))
    hit = cur.fetchone()
    if hit:
        in_db.append(r["Player Name"])
    else:
        not_in_db.append(r["Player Name"])

nations = yaml.safe_load((ROOT / "tool/etl/config/nations_allowlist.yaml").read_text(encoding="utf-8"))["nations"]
clubs = yaml.safe_load((ROOT / "tool/etl/config/clubs_allowlist.yaml").read_text(encoding="utf-8"))["clubs"]

csv_nats = Counter(r["Nationality"].strip() for r in rows)
missing_nats = [n for n in csv_nats if n not in nations]

club_names = set()
for r in rows:
    for c in (r.get("Senior Clubs Played For") or "").split(","):
        club_names.add(c.strip())
missing_clubs = sorted(c for c in club_names if c and c not in clubs)

print("total", len(rows))
print("already_in_db", len(in_db))
print("not_in_db", len(not_in_db))
print("missing_nations", missing_nats)
print("clubs_in_csv", len(club_names))
print("clubs_not_in_allowlist", len(missing_clubs))
print("sample_missing_clubs", missing_clubs[:25])
