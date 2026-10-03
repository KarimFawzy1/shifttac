#!/usr/bin/env python3
"""Phase D12 — run frozen validation_cases.yaml against tiki_taka.db.

Uses the same validation SQL as runtime (dataset-plan.md).

Writes:
  tool/etl/reports/run_validation_cases_summary.json

Exit 0 when all cases pass; 1 otherwise.

Re-run after each monthly CSV refresh:
  python tool/etl/build_database.py
  python tool/etl/run_validation_cases.py
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

try:
    import yaml
except ImportError as exc:
    raise SystemExit("Install PyYAML: pip install pyyaml") from exc

from etl_common import REPORTS, ROOT  # noqa: E402

FIXTURES_PATH = _ETL_DIR / "fixtures" / "validation_cases.yaml"
SUMMARY_PATH = REPORTS / "run_validation_cases_summary.json"
DEFAULT_DB = ROOT / "assets" / "db" / "tiki_taka.db"

VALIDATION_SQL = """
SELECT DISTINCT p.id
FROM players p
INNER JOIN player_attributes a
  ON a.player_id = p.id AND a.attribute_id = ?
INNER JOIN player_attributes b
  ON b.player_id = p.id AND b.attribute_id = ?
WHERE p.id = ?
"""


def tm_id(raw: str) -> str:
    raw = str(raw).strip()
    return raw if raw.startswith("tm:") else f"tm:{raw}"


def canonical_pair(attr_a: str, attr_b: str) -> tuple[str, str]:
    return (attr_a, attr_b) if attr_a < attr_b else (attr_b, attr_a)


def load_fixtures(path: Path | None = None) -> dict[str, Any]:
    fixture_path = path or FIXTURES_PATH
    if not fixture_path.is_file():
        raise FileNotFoundError(f"Missing fixtures: {fixture_path}")
    with fixture_path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def resolve_db_path(fixtures: dict[str, Any], override: Path | None) -> Path:
    if override is not None:
        return override
    rel = fixtures.get("db_path", "assets/db/tiki_taka.db")
    return ROOT / rel


def player_has_intersection(
    connection: sqlite3.Connection,
    player_id: str,
    row_attr: str,
    col_attr: str,
) -> bool:
    pid = tm_id(player_id)
    row = connection.execute(
        VALIDATION_SQL, (row_attr, col_attr, pid)
    ).fetchone()
    return row is not None


def run_player_intersection(
    connection: sqlite3.Connection, case: dict[str, Any]
) -> str | None:
    row_attr = case["row_attr"]
    col_attr = case["col_attr"]
    player_id = case["player_id"]
    expected = case["expected"]
    matched = player_has_intersection(connection, player_id, row_attr, col_attr)
    if expected == "valid" and not matched:
        return f"expected valid intersection for {tm_id(player_id)}"
    if expected == "invalid" and matched:
        return f"expected no intersection for {tm_id(player_id)}"
    return None


def run_alias_lookup(connection: sqlite3.Connection, case: dict[str, Any]) -> str | None:
    alias = case["alias"]
    expected = tm_id(case["expected_player_id"])
    row = connection.execute(
        "SELECT player_id FROM player_aliases WHERE alias = ?",
        (alias,),
    ).fetchone()
    if row is None:
        return f"alias '{alias}' not found"
    if row[0] != expected:
        return f"alias '{alias}' -> {row[0]}, expected {expected}"
    return None


def run_pair_stats(connection: sqlite3.Connection, case: dict[str, Any]) -> str | None:
    attr_a, attr_b = canonical_pair(case["row_attr"], case["col_attr"])
    row = connection.execute(
        """
        SELECT player_count, sample_player_ids
        FROM attribute_pair_stats
        WHERE attr_a = ? AND attr_b = ?
        """,
        (attr_a, attr_b),
    ).fetchone()
    count = int(row[0]) if row else 0
    sample_json = row[1] if row else "[]"

    if "min_player_count" in case and count < int(case["min_player_count"]):
        return f"player_count {count} < min {case['min_player_count']}"

    if "max_player_count" in case and count > int(case["max_player_count"]):
        return f"player_count {count} > max {case['max_player_count']}"

    if sample_player := case.get("sample_includes_player_id"):
        try:
            samples = json.loads(sample_json)
        except json.JSONDecodeError:
            return "sample_player_ids is not valid JSON"
        if tm_id(sample_player) not in samples:
            return f"{tm_id(sample_player)} not in sample_player_ids"
    return None


def run_board_count(connection: sqlite3.Connection, case: dict[str, Any]) -> str | None:
    count = connection.execute("SELECT COUNT(*) FROM boards").fetchone()[0]
    minimum = int(case["min_boards"])
    if count < minimum:
        return f"board count {count} < min {minimum}"
    return None


def run_player_search(connection: sqlite3.Connection, case: dict[str, Any]) -> str | None:
    prefix = case["search_prefix"]
    min_results = int(case.get("min_results", 1))
    must_include = tm_id(case["must_include_player_id"])
    rows = connection.execute(
        """
        SELECT p.id
        FROM players p
        WHERE p.search_text LIKE ? || '%'
        LIMIT 20
        """,
        (prefix,),
    ).fetchall()
    ids = [row[0] for row in rows]
    if len(ids) < min_results:
        return f"prefix '{prefix}' returned {len(ids)} rows, need >= {min_results}"
    if must_include not in ids:
        return f"{must_include} not in search results for '{prefix}'"
    return None


RUNNERS = {
    "player_intersection": run_player_intersection,
    "alias_lookup": run_alias_lookup,
    "pair_stats": run_pair_stats,
    "board_count": run_board_count,
    "player_search": run_player_search,
}


def run_cases(
    db_path: Path,
    fixtures_path: Path | None = None,
    *,
    quiet: bool = False,
) -> tuple[int, dict[str, Any]]:
    fixtures = load_fixtures(fixtures_path)
    cases = fixtures.get("cases") or []
    if not cases:
        raise ValueError("validation_cases.yaml has no cases")

    if not db_path.is_file():
        raise FileNotFoundError(
            f"Database not found: {db_path} (run tool/etl/build_database.py first)"
        )

    uri = db_path.resolve().as_uri() + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True)
    results: list[dict[str, Any]] = []
    failures: list[str] = []

    try:
        for case in cases:
            case_id = case.get("id", "<unknown>")
            case_type = case.get("type")
            runner = RUNNERS.get(case_type or "")
            if runner is None:
                error = f"unknown case type: {case_type}"
            else:
                error = runner(connection, case)

            passed = error is None
            results.append(
                {
                    "id": case_id,
                    "type": case_type,
                    "expected": case.get("expected"),
                    "passed": passed,
                    "error": error,
                }
            )
            if not passed:
                failures.append(f"{case_id}: {error}")
    finally:
        connection.close()

    summary = {
        "phase": "D12",
        "run_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "db_path": str(db_path),
        "fixtures": str(fixtures_path or FIXTURES_PATH),
        "case_count": len(cases),
        "passed_count": sum(1 for r in results if r["passed"]),
        "failed_count": len(failures),
        "validation_passed": not failures,
        "results": results,
        "failures": failures,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    with SUMMARY_PATH.open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2)
        handle.write("\n")

    if not quiet:
        status = "OK" if not failures else "FAILED"
        print(
            f"D12 validation {status}: {summary['passed_count']}/{summary['case_count']} cases"
        )
        print(f"  db: {db_path}")
        print(f"  report: {SUMMARY_PATH}")
        for err in failures:
            print(f"  - {err}", file=sys.stderr)

    return (0 if not failures else 1), summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Run D12 validation_cases.yaml")
    parser.add_argument(
        "--db",
        type=Path,
        default=None,
        help="SQLite path (default: assets/db/tiki_taka.db)",
    )
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=FIXTURES_PATH,
        help="Path to validation_cases.yaml",
    )
    args = parser.parse_args()

    try:
        fixtures = load_fixtures(args.fixtures)
        db_path = resolve_db_path(fixtures, args.db)
        code, _ = run_cases(db_path, args.fixtures)
        return code
    except (FileNotFoundError, ValueError) as exc:
        print(f"D12 validation FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
