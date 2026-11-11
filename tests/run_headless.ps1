param(
    [string]$GodotPath = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot "apps\player-godot"

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $godotCommand) {
        $GodotPath = $godotCommand.Source
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $managedGodot = Join-Path $env:LOCALAPPDATA "CineWeave\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    if (Test-Path -LiteralPath $managedGodot) {
        $GodotPath = $managedGodot
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath)) {
    Write-Error "Godot 4.7.2 was not found. Pass -GodotPath or set GODOT_BIN."
    exit 2
}

$consoleGodot = $GodotPath -replace "\.exe$", "_console.exe"
if ($GodotPath -notmatch "_console\.exe$" -and (Test-Path -LiteralPath $consoleGodot)) {
    $GodotPath = $consoleGodot
}

$output = & $GodotPath --headless --path $projectPath --script "res://tests/run_all.gd" 2>&1
$godotExitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Output $_ }

$passMarker = "PASS: CineWeave Godot startup baseline"
if ($godotExitCode -ne 0 -or $output -notcontains $passMarker) {
    exit 1
}

exit 0
