#!/usr/bin/env python3
"""Phase T0 — preflight gate before Flutter Tiki-Taka gameplay work (T1+).

Runs D12 validation, asset coverage validation, checks G1–G7 artifacts,
and writes tool/etl/reports/tiki_taka_preflight_gate.json.

Usage:
  python tool/etl/run_tiki_taka_preflight_gate.py
  flutter test test/features/tiki_taka/release/tiki_taka_database_smoke_test.dart \\
    test/features/tiki_taka/domain/services/tiki_taka_attribute_assets_test.dart \\
    test/features/tiki_taka/domain/services/tiki_taka_attribute_manifest_test.dart
"""

from __future__ import annotations

import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

_USE_SHELL = platform.system() == "Windows"

REPO_ROOT = Path(__file__).resolve().parents[2]
ETL_DIR = Path(__file__).resolve().parent
REPORT_PATH = ETL_DIR / "reports" / "tiki_taka_preflight_gate.json"

G1_G7_CHECKS: tuple[tuple[str, Path], ...] = (
    ("G1_pubspec_attribute_assets", REPO_ROOT / "pubspec.yaml"),
    ("G2_attribute_manifest", REPO_ROOT / "assets" / "tiki_taka" / "attrs" / "manifest.json"),
    ("G2_manifest_generator", ETL_DIR / "generate_attribute_asset_manifest.py"),
    ("G3_asset_validator", ETL_DIR / "validate_attribute_assets.py"),
    ("G4_pubspec_lock", REPO_ROOT / "pubspec.lock"),
    ("G5_db_contract", REPO_ROOT / "docs" / "tiki-taka-database-contract.md"),
    ("G5_db_stub", REPO_ROOT / "lib" / "features" / "tiki_taka" / "data" / "local" / "tiki_taka_database.dart"),
    ("G5_paths_stub", REPO_ROOT / "lib" / "features" / "tiki_taka" / "data" / "local" / "tiki_taka_database_paths.dart"),
    ("G6_rules_doc", REPO_ROOT / "docs" / "tiki-taka-toe-rules.md"),
    ("G7_feature_readme", REPO_ROOT / "lib" / "features" / "tiki_taka" / "README.md"),
    ("G7_feature_scaffold", REPO_ROOT / "lib" / "features" / "tiki_taka" / "presentation" / "screens"),
    ("shipped_db", REPO_ROOT / "assets" / "db" / "tiki_taka.db"),
)


def _read_pubspec_runtime_deps(pubspec_path: Path) -> dict[str, bool]:
    text = pubspec_path.read_text(encoding="utf-8")
    section: str | None = None
    deps: dict[str, bool] = {}
    for raw_line in text.splitlines():
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        indent = len(raw_line) - len(raw_line.lstrip())
        line = raw_line.strip()
        if indent == 0 and line == "dependencies:":
            section = "dependencies"
            continue
        if indent == 0 and line == "dev_dependencies:":
            section = "dev_dependencies"
            continue
        if indent == 0 and line.endswith(":"):
            section = None
            continue
        if section not in {"dependencies", "dev_dependencies"} or ":" not in line:
            continue
        if indent != 2:
            continue
        name = line.split(":", 1)[0].strip()
        if name:
            deps[name] = section == "dependencies"
    return deps


def _check_g1_g7() -> tuple[list[dict[str, object]], list[str]]:
    checks: list[dict[str, object]] = []
    errors: list[str] = []

    for check_id, path in G1_G7_CHECKS:
        ok = path.is_file() or path.is_dir()
        checks.append({"id": check_id, "path": str(path.relative_to(REPO_ROOT)).replace("\\", "/"), "passed": ok})
        if not ok:
            errors.append(f"Missing artifact: {check_id} ({path})")

    pubspec = REPO_ROOT / "pubspec.yaml"
    if pubspec.is_file():
        deps = _read_pubspec_runtime_deps(pubspec)
        for package in ("sqflite", "path", "path_provider"):
            ok = deps.get(package, False)
            checks.append({"id": f"G4_runtime_{package}", "path": "pubspec.yaml", "passed": ok})
            if not ok:
                errors.append(f"G4: {package} is not a runtime dependency")
        ffi_dev = not deps.get("sqflite_common_ffi", True)
        checks.append({"id": "G4_sqflite_common_ffi_dev_only", "path": "pubspec.yaml", "passed": ffi_dev})
        if not ffi_dev:
            errors.append("G4: sqflite_common_ffi must remain dev-only")

    if pubspec.is_file():
        text = pubspec.read_text(encoding="utf-8")
        for asset in (
            "assets/tiki_taka/attrs/clubs/",
            "assets/tiki_taka/attrs/leagues/",
            "assets/tiki_taka/attrs/nations/",
            "assets/tiki_taka/attrs/manifest.json",
        ):
            ok = asset in text
            checks.append({"id": f"G1_asset_{asset}", "path": "pubspec.yaml", "passed": ok})
            if not ok:
                errors.append(f"G1: pubspec missing asset entry {asset}")

    manifest = REPO_ROOT / "assets" / "tiki_taka" / "attrs" / "manifest.json"
    if manifest.is_file():
        entries = json.loads(manifest.read_text(encoding="utf-8"))
        ok = len(entries) == 153
        checks.append({"id": "G2_manifest_entry_count", "path": str(manifest.relative_to(REPO_ROOT)), "passed": ok, "count": len(entries)})
        if not ok:
            errors.append(f"G2: expected 153 manifest entries, found {len(entries)}")

    return checks, errors


FLUTTER_TESTS = (
    "test/features/tiki_taka/release/tiki_taka_database_smoke_test.dart",
    "test/features/tiki_taka/domain/services/tiki_taka_attribute_assets_test.dart",
    "test/features/tiki_taka/domain/services/tiki_taka_attribute_manifest_test.dart",
)


def _run_python_step(script_name: str, step_id: str) -> tuple[dict[str, object], list[str]]:
    script = ETL_DIR / script_name
    errors: list[str] = []
    if not script.is_file():
        return {"id": step_id, "passed": False, "error": f"script not found: {script}"}, [f"{step_id}: script missing"]

    completed = subprocess.run(
        [sys.executable, str(script)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    passed = completed.returncode == 0
    result = {
        "id": step_id,
        "passed": passed,
        "exit_code": completed.returncode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
    }
    if not passed:
        errors.append(f"{step_id} failed (exit {completed.returncode})")
    return result, errors


def _run_flutter_tests() -> tuple[list[dict[str, object]], list[str]]:
    results: list[dict[str, object]] = []
    errors: list[str] = []

    for test_path in FLUTTER_TESTS:
        completed = subprocess.run(
            f"flutter test {test_path}",
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            shell=_USE_SHELL,
        )
        passed = completed.returncode == 0
        results.append(
            {
                "id": test_path,
                "passed": passed,
                "exit_code": completed.returncode,
            }
        )
        if not passed:
            errors.append(f"Flutter test failed: {test_path}")

    analyze = subprocess.run(
        "flutter analyze",
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        shell=_USE_SHELL,
    )
    analyze_passed = analyze.returncode == 0
    results.append(
        {
            "id": "flutter_analyze",
            "passed": analyze_passed,
            "exit_code": analyze.returncode,
        }
    )
    if not analyze_passed:
        errors.append("flutter analyze failed")

    return results, errors


def main() -> int:
    gap_checks, gap_errors = _check_g1_g7()

    d12_result, d12_errors = _run_python_step("run_validation_cases.py", "D12_validation_cases")
    g3_result, g3_errors = _run_python_step("validate_attribute_assets.py", "G3_asset_coverage")
    flutter_results, flutter_errors = _run_flutter_tests()

    errors = gap_errors + d12_errors + g3_errors + flutter_errors
    passed = not errors

    report = {
        "phase": "T0",
        "gate": "tiki_taka_preflight",
        "run_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "status": "pass" if passed else "fail",
        "blocking_gaps_before_t1": len(errors),
        "gap_closure_checks": gap_checks,
        "automated_steps": [d12_result, g3_result],
        "flutter_verification": flutter_results,
        "d12_case_count": 18,
        "d12_passed_count": 18 if d12_result.get("passed") else 0,
        "g1_g7_checklist": {
            "G1_pubspec_assets_registered": not any(
                e.startswith("G1:") for e in gap_errors
            ),
            "G2_manifest_complete": not any(
                e.startswith("G2:") for e in gap_errors
            ),
            "G3_asset_validation_passes": g3_result.get("passed", False),
            "G4_runtime_deps_added": not any(
                e.startswith("G4:") for e in gap_errors
            ),
            "G5_db_contract_documented": not any(
                "G5" in check["id"] and not check["passed"] for check in gap_checks
            ),
            "G6_rules_locked": not any(
                "G6" in check["id"] and not check["passed"] for check in gap_checks
            ),
            "G7_feature_scaffold_present": not any(
                "G7" in check["id"] and not check["passed"] for check in gap_checks
            ),
        },
        "errors": errors,
        "next_phase": "T1" if passed else "resolve_T0_failures",
    }

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    if passed:
        print("T0 preflight gate OK — G1–G7 closed, D12 and asset validation passed")
        print(f"  report: {REPORT_PATH}")
        return 0

    print("T0 preflight gate FAILED:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    print(f"  report: {REPORT_PATH}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
