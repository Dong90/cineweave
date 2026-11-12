param(
    [string]$GodotPath = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectSourcePath = Join-Path $repoRoot "apps\player-godot"
$engineVersionPath = Join-Path $repoRoot "engine\version.json"
$godotResolverPath = Join-Path $repoRoot "tools\godot\resolve_godot.ps1"
$releaseHelpersPath = Join-Path $repoRoot "tools\release\release_helpers.ps1"

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

. $godotResolverPath
. $releaseHelpersPath
try {
    $GodotPath = Resolve-CineWeaveGodot -GodotPath $GodotPath -EngineVersion $engineVersion
}
catch {
    Write-Error $_.Exception.Message
    exit 2
}

$temporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$temporaryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $temporaryBase ("cineweave-headless-" + [guid]::NewGuid().ToString("N")))
)
if (-not $temporaryRoot.StartsWith("$temporaryBase\", [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "Unsafe temporary Player path: $temporaryRoot"
    exit 2
}
$projectPath = Join-Path $temporaryRoot "player-godot"
$testExitCode = 1

try {
    New-Item -ItemType Directory -Path $projectPath | Out-Null
    Get-ChildItem -LiteralPath $projectSourcePath -Force |
        Where-Object { $_.Name -ne ".godot" } |
        Copy-Item -Destination $projectPath -Recurse -Force

    $importOutput = & $GodotPath --headless --path $projectPath --import 2>&1
    $importExitCode = $LASTEXITCODE
    $importOutput | ForEach-Object { Write-Output $_ }
    if ($importExitCode -ne 0) {
        Write-Error "Godot failed to import Player assets before the headless test."
    }
    else {
        $output = & $GodotPath --headless --path $projectPath --script "res://tests/run_all.gd" 2>&1
        $godotExitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Output $_ }

        $passMarker = "PASS: CineWeave Godot startup baseline"
        if ($godotExitCode -eq 0 -and $output -contains $passMarker) {
            $testExitCode = 0
        }
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
        Remove-CineWeaveExactDirectory -Path $temporaryRoot
    }
}

exit $testExitCode
