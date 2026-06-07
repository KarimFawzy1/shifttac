# Phase T12 — run release-gate checks for Tiki-Taka (budgets + bounded tests).
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

Write-Host "== Tiki-Taka release budget check =="
python tool/release/check_tiki_taka_release_budgets.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== Tiki-Taka release tests (bounded, no timer hangs) =="
flutter test `
  test/features/tiki_taka/release `
  test/tiki_taka_database_smoke_test.dart `
  test/features/tiki_taka/presentation/screens/tiki_taka_entry_screen_test.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK: Tiki-Taka release checks passed"
