#!/usr/bin/env python3
"""Check and optionally remove stripped nation edges from tiki_taka.db."""
from __future__ import annotations

import argparse
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "assets" / "db" / "tiki_taka.db"
OUTPUT_DB = ROOT / "tool" / "etl" / "output" / "tiki_taka.db"
REPORT_PATH = ROOT / "legendary-players" / "reports" / "stripped_nations_db_audit.json"

STRIPPED_NATIONS: dict[str, str] = {
    "north_macedonia": "North Macedonia",
    "iran": "Iran",
    "georgia": "Georgia",
    "paraguay": "Paraguay",
    "zambia": "Zambia",
    "south_africa": "South Africa",
    "new_zealand": "New Zealand",
    "montenegro": "Montenegro",
}


def audit(conn: sqlite3.Connection) -> dict[str, object]:
    slugs = list(STRIPPED_NATIONS.keys())
    attr_ids = [f"nation:{slug}" for slug in slugs]

    nation_attrs = conn.execute(
        """
        SELECT id, display_name, slug
        FROM attributes
        WHERE type = 'nation'
        AND (slug IN ({}) OR id IN ({}))
        """.format(
            ",".join("?" * len(slugs)),
            ",".join("?" * len(attr_ids)),
        ),
        slugs + attr_ids,
    ).fetchall()

    player_edges = conn.execute(
        """
        SELECT pa.player_id, pa.attribute_id, pa.source, p.display_name
        FROM player_attributes pa
        LEFT JOIN players p ON p.id = pa.player_id
        WHERE pa.attribute_id IN ({})
        ORDER BY pa.attribute_id, pa.player_id
        """.format(",".join("?" * len(attr_ids))),
        attr_ids,
    ).fetchall()

    return {
        "stripped_nation_attributes": [
            {"id": row[0], "display_name": row[1], "slug": row[2]} for row in nation_attrs
        ],
        "player_attribute_edges": [
            {
                "player_id": row[0],
                "attribute_id": row[1],
                "source": row[2],
                "display_name": row[3],
            }
            for row in player_edges
        ],
        "attribute_count": len(nation_attrs),
        "edge_count": len(player_edges),
    }


def purge(conn: sqlite3.Connection) -> dict[str, int]:
    attr_ids = [f"nation:{slug}" for slug in STRIPPED_NATIONS]
    cur = conn.cursor()
    cur.execute(
        f"""
        DELETE FROM player_attributes
        WHERE attribute_id IN ({",".join("?" * len(attr_ids))})
        """,
        attr_ids,
    )
    deleted_edges = cur.rowcount

    cur.execute(
        f"""
        DELETE FROM attributes
        WHERE type = 'nation'
        AND (slug IN ({",".join("?" * len(attr_ids))}) OR id IN ({",".join("?" * len(attr_ids))}))
        """,
        list(STRIPPED_NATIONS.keys()) + attr_ids,
    )
    deleted_attrs = cur.rowcount

    cur.execute(
        f"""
        DELETE FROM attribute_pair_stats
        WHERE attr_a IN ({",".join("?" * len(attr_ids))})
           OR attr_b IN ({",".join("?" * len(attr_ids))})
        """,
        attr_ids + attr_ids,
    )
    deleted_pairs = cur.rowcount

    conn.commit()
    return {
        "deleted_player_attributes": deleted_edges,
        "deleted_attributes": deleted_attrs,
        "deleted_attribute_pair_stats": deleted_pairs,
    }


def process_db(db_path: Path, *, apply: bool) -> dict[str, object]:
    if not db_path.is_file():
        return {"path": str(db_path), "skipped": True}

    conn = sqlite3.connect(db_path)
    before = audit(conn)
    result: dict[str, object] = {"path": str(db_path), "before": before}
    if apply and (before["edge_count"] or before["attribute_count"]):
        result["deleted"] = purge(conn)
        result["after"] = audit(conn)
    else:
        result["after"] = before
    conn.close()
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Delete stripped nation data")
    args = parser.parse_args()

    results = [process_db(DB_PATH, apply=args.apply)]
    if OUTPUT_DB.is_file():
        results.append(process_db(OUTPUT_DB, apply=args.apply))

    report = {
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "stripped_nations": STRIPPED_NATIONS,
        "apply": args.apply,
        "databases": results,
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    total_edges = sum(r["before"]["edge_count"] for r in results if "before" in r)
    total_attrs = sum(r["before"]["attribute_count"] for r in results if "before" in r)
    print(f"Report: {REPORT_PATH}")
    print(f"Stripped nation attributes: {total_attrs}")
    print(f"Stripped nation player edges: {total_edges}")

    if total_edges or total_attrs:
        for db in results:
            if db.get("skipped"):
                continue
            print(f"\n{db['path']}:")
            for edge in db["before"]["player_attribute_edges"][:20]:
                print(f"  {edge['display_name']} ({edge['player_id']}) -> {edge['attribute_id']}")
            if args.apply and db.get("deleted"):
                print(f"  Deleted: {db['deleted']}")
        return 0 if args.apply else 1

    print("OK: no stripped nation attributes or player edges found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
