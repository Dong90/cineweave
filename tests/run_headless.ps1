param(
    [string]$GodotPath = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot "apps\player-godot"
$engineVersionPath = Join-Path $repoRoot "engine\version.json"

if (-not (Test-Path -LiteralPath $engineVersionPath -PathType Leaf)) {
    Write-Error "Engine version manifest was not found: $engineVersionPath"
    exit 2
}

try {
    $engineVersion = Get-Content -LiteralPath $engineVersionPath -Encoding UTF8 -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Engine version manifest is invalid: $engineVersionPath"
    exit 2
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $godotCommand) {
        $GodotPath = $godotCommand.Source
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $managedGodot = Join-Path $env:LOCALAPPDATA (
        "CineWeave\tools\godot\{0}\{1}" -f `
            $engineVersion.godot_version,
            $engineVersion.official_windows_console_executable
    )
    if (Test-Path -LiteralPath $managedGodot) {
        $GodotPath = $managedGodot
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath)) {
    Write-Error "Godot $($engineVersion.godot_version) was not found. Pass -GodotPath or set GODOT_BIN."
    exit 2
}

$consoleGodot = $GodotPath -replace "\.exe$", "_console.exe"
if ($GodotPath -notmatch "_console\.exe$" -and (Test-Path -LiteralPath $consoleGodot)) {
    $GodotPath = $consoleGodot
}

$importOutput = & $GodotPath --headless --path $projectPath --import 2>&1
$importExitCode = $LASTEXITCODE
$importOutput | ForEach-Object { Write-Output $_ }
if ($importExitCode -ne 0) {
    Write-Error "Godot failed to import Player assets before the headless test."
    exit 1
}

$output = & $GodotPath --headless --path $projectPath --script "res://tests/run_all.gd" 2>&1
$godotExitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Output $_ }

$passMarker = "PASS: CineWeave Godot startup baseline"
if ($godotExitCode -ne 0 -or $output -notcontains $passMarker) {
    exit 1
}

exit 0
