#!/usr/bin/env python3
"""Audit top-50 famous players for missing pre-2012 club edges in tiki_taka.db."""
from __future__ import annotations

import sqlite3
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
DB = REPO / "assets" / "db" / "tiki_taka.db"

CLUBS = {
    "Manchester United": "985",
    "Ajax": "610",
    "Inter Milan": "46",
    "Juventus": "506",
    "Barcelona": "131",
    "Chelsea": "631",
    "AC Milan": "5",
    "Atletico Madrid": "13",
    "Arsenal": "11",
    "Valencia": "1049",
    "Lyon": "1041",
    "Tottenham Hotspur": "148",
    "Liverpool": "31",
    "Manchester City": "281",
    "Real Madrid": "418",
    "Sevilla": "368",
    "Santos": "221",
    "Porto": "720",
    "Monaco": "162",
    "Bayern Munich": "27",
    "Borussia Dortmund": "16",
    "Everton": "29",
    "Roma": "12",
}

PLAYERS: list[tuple[str, str, list[str]]] = [
    ("8198", "Cristiano Ronaldo", ["Manchester United"]),
    ("22138", "Zlatan Ibrahimovic", ["Ajax", "Inter Milan", "Juventus", "Barcelona"]),
    ("3139", "David Beckham", ["Manchester United"]),
    ("3332", "Wayne Rooney", ["Manchester United"]),
    ("3751", "Frank Lampard", ["Chelsea"]),
    ("4257", "Samuel Eto'o", ["Barcelona"]),
    ("3359", "Kaka", ["AC Milan"]),
    ("5813", "Andrea Pirlo", ["AC Milan"]),
    ("26399", "Sergio Aguero", ["Atletico Madrid"]),
    ("8806", "Cesc Fabregas", ["Arsenal", "Barcelona"]),
    ("10782", "David Silva", ["Valencia"]),
    ("7943", "David Villa", ["Valencia", "Barcelona", "Atletico Madrid"]),
    ("18922", "Karim Benzema", ["Lyon"]),
    ("27992", "Luka Modric", ["Tottenham Hotspur"]),
    ("173095", "Gareth Bale", ["Tottenham Hotspur"]),
    ("4247", "Robin van Persie", ["Arsenal"]),
    ("7536", "Xabi Alonso", ["Liverpool"]),
    ("7106", "Fernando Torres", ["Liverpool", "Chelsea"]),
    ("4144", "Didier Drogba", ["Chelsea"]),
    ("3180", "Ashley Cole", ["Arsenal", "Chelsea"]),
    ("1185", "Petr Cech", ["Chelsea"]),
    ("3160", "John Terry", ["Chelsea"]),
    ("4272", "Carlos Tevez", ["Manchester City"]),
    ("4360", "Arjen Robben", ["Chelsea", "Real Madrid"]),
    ("4673", "Wesley Sneijder", ["Inter Milan"]),
    ("15951", "Dani Alves", ["Sevilla", "Barcelona"]),
    ("18944", "Gerard Pique", ["Barcelona"]),
    ("3979", "Iker Casillas", ["Real Madrid"]),
    ("25557", "Sergio Ramos", ["Real Madrid"]),
    ("3368", "Marcelo", ["Real Madrid"]),
    ("5023", "Gianluigi Buffon", ["Juventus"]),
    ("68290", "Neymar", ["Santos", "Barcelona"]),
    ("44352", "Luis Suarez", ["Liverpool", "Barcelona"]),
    ("27684", "Alexis Sanchez", ["Barcelona", "Arsenal"]),
    ("39152", "Radamel Falcao", ["Porto", "Atletico Madrid"]),
    ("93938", "Diego Costa", ["Atletico Madrid"]),
    ("88103", "James Rodriguez", ["Monaco", "Real Madrid"]),
    ("89482", "Paul Pogba", ["Juventus"]),
    ("88", "Bastian Schweinsteiger", ["Bayern Munich"]),
    ("58857", "Toni Kroos", ["Bayern Munich"]),
    ("570", "Philipp Lahm", ["Bayern Munich"]),
    ("17259", "Manuel Neuer", ["Bayern Munich"]),
    ("38272", "Robert Lewandowski", ["Borussia Dortmund"]),
    ("50202", "Eden Hazard", ["Chelsea"]),
    ("88755", "Kevin De Bruyne", ["Chelsea"]),
    ("65706", "Romelu Lukaku", ["Chelsea", "Everton"]),
    ("128223", "Alvaro Morata", ["Real Madrid", "Juventus"]),
    ("134425", "Raheem Sterling", ["Liverpool"]),
    ("148455", "Mohamed Salah", ["Chelsea", "Roma"]),
    ("7607", "Xavi", ["Barcelona"]),
]


def main() -> int:
    conn = sqlite3.connect(DB)
    cur = conn.cursor()

    missing_edges: list[tuple[str, str, str, str]] = []
    not_in_db: list[tuple[str, str]] = []
    complete: list[str] = []

    for pid, name, expected_clubs in PLAYERS:
        cur.execute("SELECT id FROM players WHERE id = ?", (f"tm:{pid}",))
        if not cur.fetchone():
            not_in_db.append((pid, name))
            continue

        cur.execute(
            """
            SELECT DISTINCT attribute_id
            FROM player_attributes
            WHERE player_id = ? AND attribute_id LIKE 'club:%'
            """,
            (f"tm:{pid}",),
        )
        have = {row[0].split(":", 1)[1] for row in cur.fetchall()}
        player_missing = False
        for club in expected_clubs:
            cid = CLUBS[club]
            if cid not in have:
                missing_edges.append((pid, name, club, cid))
                player_missing = True
        if not player_missing:
            complete.append(name)

    print(f"NOT IN DB ({len(not_in_db)}):")
    for pid, name in not_in_db:
        print(f"  {name} ({pid})")

    print(f"\nCOMPLETE — no missing expected clubs ({len(complete)}):")
    for name in complete:
        print(f"  {name}")

    print(f"\nMISSING EDGES ({len(missing_edges)}):")
    for pid, name, club, cid in missing_edges:
        print(f"  {name} ({pid}) -> {club} (club:{cid})")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
