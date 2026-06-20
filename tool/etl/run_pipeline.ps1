# Tiki-Taka ETL pipeline including legendary player supplements.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

$steps = @(
    @{ Label = "D1 ingest raw"; Script = "tool/etl/ingest_raw.py" },
    @{ Label = "D2 normalize"; Script = "tool/etl/normalize_dimensions.py" },
    @{ Label = "D3 merge clubs"; Script = "tool/etl/merge_player_club.py" },
    @{ Label = "D4 derive leagues"; Script = "tool/etl/derive_player_league.py" },
    @{ Label = "D5 derive nations"; Script = "tool/etl/derive_player_nation.py" },
    @{ Label = "D6 derive positions"; Script = "tool/etl/derive_player_position.py" },
    @{ Label = "Legendary ingest"; Script = "tool/etl/ingest_legendary_players.py" },
    @{ Label = "Legendary merge"; Script = "tool/etl/merge_legendary_supplements.py" },
    @{ Label = "D7 build players"; Script = "tool/etl/build_players.py" }
)

foreach ($step in $steps) {
    Write-Host ""
    Write-Host "=== $($step.Label): $($step.Script) ==="
    python $step.Script
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host ""
Write-Host "Pipeline complete."
