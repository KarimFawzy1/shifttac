#!/usr/bin/env python3
"""Merge auto + manual TM ID rows into one complete CSV."""

from __future__ import annotations

import csv
import json
import ssl
import urllib.parse
import urllib.request
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
SOURCE_CSV = BASE_DIR / "legendary_players.csv"
AUTO_CSV = BASE_DIR / "legendary_players_with_tm_id.csv"
MANUAL_CSV = BASE_DIR / "legendary_players_manual_review.csv"
OUTPUT_CSV = BASE_DIR / "legendary_players_with_tm_id.csv"

OUTPUT_FIELDS = [
    "Player Name",
    "Nationality",
    "DOB",
    "Position",
    "Senior Clubs Played For",
    "transfermarkt_id",
    "wikidata_qid",
]

WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"
USER_AGENT = "ShiftTac-LegendaryMerge/1.0"


def fetch_wikidata(query: str) -> dict:
    params = urllib.parse.urlencode({"query": query})
    request = urllib.request.Request(
        f"{WIKIDATA_ENDPOINT}?{params}",
        headers={"Accept": "application/sparql-results+json", "User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception as error:
        if "CERTIFICATE_VERIFY_FAILED" not in str(error):
            raise
        context = ssl._create_unverified_context()
        with urllib.request.urlopen(request, timeout=30, context=context) as response:
            return json.loads(response.read().decode("utf-8"))


def lookup_qids_by_tm_ids(tm_ids: list[str]) -> dict[str, str]:
    if not tm_ids:
        return {}
    values = " ".join(f'"{tm_id}"' for tm_id in tm_ids)
    query = f"""
SELECT ?tmId ?player WHERE {{
  VALUES ?tmId {{ {values} }}
  ?player wdt:P2446 ?tmId .
}}
""".strip()
    payload = fetch_wikidata(query)
    mapping: dict[str, str] = {}
    for row in payload.get("results", {}).get("bindings", []):
        tm_id = row.get("tmId", {}).get("value", "").strip()
        qid = row.get("player", {}).get("value", "").rsplit("/", 1)[-1]
        if tm_id and qid and tm_id not in mapping:
            mapping[tm_id] = qid
    return mapping


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as file:
        return list(csv.DictReader(file))


def main() -> None:
    source_rows = load_rows(SOURCE_CSV)
    auto_rows = load_rows(AUTO_CSV)
    manual_rows = load_rows(MANUAL_CSV)

    by_name: dict[str, dict[str, str]] = {}
    for row in auto_rows:
        by_name[row["Player Name"]] = {
            "transfermarkt_id": row.get("transfermarkt_id", "").strip(),
            "wikidata_qid": row.get("wikidata_qid", "").strip(),
        }
    for row in manual_rows:
        by_name[row["Player Name"]] = {
            "transfermarkt_id": row.get("transfermarkt_id", "").strip(),
            "wikidata_qid": row.get("wikidata_qid", "").strip(),
        }

    missing_qid_tm_ids = sorted(
        {
            data["transfermarkt_id"]
            for data in by_name.values()
            if data["transfermarkt_id"] and not data["wikidata_qid"]
        }
    )
    qid_lookup = lookup_qids_by_tm_ids(missing_qid_tm_ids)
    for data in by_name.values():
        if not data["wikidata_qid"] and data["transfermarkt_id"] in qid_lookup:
            data["wikidata_qid"] = qid_lookup[data["transfermarkt_id"]]

    merged: list[dict[str, str]] = []
    for row in source_rows:
        name = row["Player Name"]
        ids = by_name.get(name, {"transfermarkt_id": "", "wikidata_qid": ""})
        merged.append(
            {
                "Player Name": name,
                "Nationality": row.get("Nationality", ""),
                "DOB": row.get("DOB", ""),
                "Position": row.get("Position", ""),
                "Senior Clubs Played For": row.get("Senior Clubs Played For", ""),
                "transfermarkt_id": ids["transfermarkt_id"],
                "wikidata_qid": ids["wikidata_qid"],
            }
        )

    with OUTPUT_CSV.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()
        writer.writerows(merged)

    without_qid = [row["Player Name"] for row in merged if row["transfermarkt_id"] and not row["wikidata_qid"]]
    without_tm = [row["Player Name"] for row in merged if not row["transfermarkt_id"]]

    print(f"Wrote {len(merged)} rows to {OUTPUT_CSV}")
    print(f"With transfermarkt_id: {sum(1 for row in merged if row['transfermarkt_id'])}")
    print(f"With wikidata_qid: {sum(1 for row in merged if row['wikidata_qid'])}")
    if without_qid:
        print(f"Missing wikidata_qid ({len(without_qid)}): {', '.join(without_qid)}")
    if without_tm:
        print(f"Missing transfermarkt_id ({len(without_tm)}): {', '.join(without_tm)}")


if __name__ == "__main__":
    main()
