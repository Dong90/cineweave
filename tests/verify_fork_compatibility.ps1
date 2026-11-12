param(
    [string]$ForkGodotPath
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$engineRoot = Join-Path $repoRoot "engine\godot"
$engineVersion = Get-Content `
    -LiteralPath (Join-Path $repoRoot "engine\version.json") `
    -Encoding UTF8 `
    -Raw | ConvertFrom-Json
$forkArtifacts = Get-Content `
    -LiteralPath (Join-Path $repoRoot "tools\godot\fork-windows-artifacts.json") `
    -Encoding UTF8 `
    -Raw | ConvertFrom-Json
. (Join-Path $repoRoot "tools\godot\resolve_godot.ps1")

if ([string]::IsNullOrWhiteSpace($ForkGodotPath)) {
    $ForkGodotPath = Join-Path $engineRoot "bin\$($forkArtifacts.console_executable)"
}
$ForkGodotPath = [System.IO.Path]::GetFullPath($ForkGodotPath)
if (-not (Test-Path -LiteralPath $engineRoot -PathType Container)) {
    throw "Pinned Godot Submodule is missing. Initialize engine/godot before Fork verification."
}

$submoduleCommit = (& git -C $engineRoot rev-parse HEAD 2>&1).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to identify the pinned Godot Submodule commit."
}
$submoduleChanges = @(& git -C $engineRoot status --porcelain --untracked-files=no 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the pinned Godot Submodule worktree."
}
if ($submoduleChanges.Count -gt 0) {
    throw "Pinned Godot Submodule contains tracked changes; reusable Fork provenance is not clean."
}

$versionOutput = ((& $ForkGodotPath --version 2>&1) -join "`n").Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Pinned Fork failed to report its version."
}
$forkPair = Resolve-CineWeaveForkGodotPair `
    -ConsolePath $ForkGodotPath `
    -VersionOutput $versionOutput `
    -SubmoduleCommit $submoduleCommit `
    -EngineVersion $engineVersion `
    -ForkArtifacts $forkArtifacts

$shellExecutable = (Get-Process -Id $PID).Path
& $shellExecutable `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File (Join-Path $repoRoot "tests\run_headless.ps1") `
    -GodotPath $forkPair.ConsolePath
if ($LASTEXITCODE -ne 0) {
    throw "Pinned Fork failed the CineWeave headless test suite."
}

Write-Output "Fork source commit: $($forkPair.SourceCommit)"
Write-Output "Fork version: $($forkPair.Version)"
Write-Output "Fork console SHA-256: $($forkPair.ConsoleSha256)"
Write-Output "Fork executable SHA-256: $($forkPair.ExecutableSha256)"
Write-Output "PASS: pinned Fork identity and CineWeave compatibility"
exit 0
