#!/usr/bin/env python3
"""Resolve famous-50 player IDs from tiki_taka.db by name."""
from __future__ import annotations

import sqlite3
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
DB = REPO / "assets" / "db" / "tiki_taka.db"

SEARCHES = [
    "Cristiano Ronaldo",
    "Zlatan Ibrahim",
    "David Beckham",
    "Wayne Rooney",
    "Frank Lampard",
    "Samuel Eto",
    "Kak",
    "Andrea Pirlo",
    "Sergio Ag",
    "Cesc F",
    "David Silva",
    "David Villa",
    "Karim Benzema",
    "Luka Modri",
    "Gareth Bale",
    "Robin van Persie",
    "Xabi Alonso",
    "Fernando Torres",
    "Didier Drogba",
    "Ashley Cole",
    "Petr",
    "John Terry",
    "Carlos Tevez",
    "Arjen Robben",
    "Wesley Sneijder",
    "Dani Alves",
    "Gerard Piqu",
    "Iker Casillas",
    "Sergio Ramos",
    "Marcelo",
    "Gianluigi Buffon",
    "Neymar",
    "Luis Su",
    "Alexis S",
    "Radamel Falcao",
    "Diego Costa",
    "James Rodr",
    "Paul Pogba",
    "Bastian Schweinsteiger",
    "Toni Kroos",
    "Philipp Lahm",
    "Manuel Neuer",
    "Robert Lewandowski",
    "Eden Hazard",
    "Kevin De Bruyne",
    "Romelu Lukaku",
    "Morata",
    "Raheem Sterling",
    "Mohamed Salah",
    "Xavi",
]

USER_IDS = {
    "Cristiano Ronaldo": "8198",
    "Zlatan Ibrahimović": "3455",
    "David Beckham": "3139",
    "Wayne Rooney": "3332",
    "Frank Lampard": "3751",
    "Samuel Eto'o": "4257",
    "Kaká": "3359",
    "Andrea Pirlo": "5813",
    "Sergio Agüero": "26399",
    "Cesc Fàbregas": "8806",
    "David Silva": "10782",
    "David Villa": "7943",
    "Karim Benzema": "18922",
    "Luka Modrić": "27992",
    "Gareth Bale": "173095",
    "Robin van Persie": "4247",
    "Xabi Alonso": "7536",
    "Fernando Torres": "7106",
    "Didier Drogba": "4144",
    "Ashley Cole": "3180",
    "Petr Čech": "1185",
    "John Terry": "3160",
    "Carlos Tevez": "4272",
    "Arjen Robben": "4360",
    "Wesley Sneijder": "4673",
    "Dani Alves": "15951",
    "Gerard Piqué": "18944",
    "Iker Casillas": "3979",
    "Sergio Ramos": "25557",
    "Marcelo": "3368",
    "Gianluigi Buffon": "5023",
    "Neymar": "68290",
    "Luis Suárez": "44352",
    "Alexis Sánchez": "27684",
    "Radamel Falcao": "39152",
    "Diego Costa": "93938",
    "James Rodríguez": "88103",
    "Paul Pogba": "89482",
    "Bastian Schweinsteiger": "88",
    "Toni Kroos": "58857",
    "Philipp Lahm": "570",
    "Manuel Neuer": "17259",
    "Robert Lewandowski": "38272",
    "Eden Hazard": "50202",
    "Kevin De Bruyne": "88755",
    "Álvaro Morata": "128223",
    "Raheem Sterling": "134425",
    "Mohamed Salah": "148455",
    "Xavi": "7607",
}


def main() -> int:
    conn = sqlite3.connect(DB)
    cur = conn.cursor()

    out_path = Path(__file__).with_name("resolve_ids_output.txt")
    lines: list[str] = []

    for prefix in SEARCHES:
        cur.execute(
            """
            SELECT id, display_name FROM players
            WHERE display_name LIKE ? OR search_text LIKE ?
            ORDER BY search_rank DESC
            LIMIT 5
            """,
            (f"{prefix}%", f"{prefix}%"),
        )
        rows = cur.fetchall()
        lines.append(f"\n=== {prefix} ===")
        for rid, name in rows:
            lines.append(f"  {rid} | {name}")

    lines.append("\n\n=== USER ID CHECK ===")
    for name, uid in USER_IDS.items():
        cur.execute("SELECT id, display_name FROM players WHERE id = ?", (f"tm:{uid}",))
        row = cur.fetchone()
        status = f"FOUND {row}" if row else "NOT IN DB"
        lines.append(f"  tm:{uid} ({name}): {status}")

    conn.close()
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
