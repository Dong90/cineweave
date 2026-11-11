[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourceRoot = Join-Path $repoRoot "content\samples\zero-echo"
$playerRoot = Join-Path $repoRoot "apps\player-godot\content\zero-echo"
$relativeFiles = @(
    "storypack.json",
    "media\zero-echo.ogv"
)

foreach ($relativeFile in $relativeFiles) {
    $sourcePath = Join-Path $sourceRoot $relativeFile
    $playerPath = Join-Path $playerRoot $relativeFile
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Authoritative StoryPack file is missing: $sourcePath"
    }

    if ($Check) {
        if (-not (Test-Path -LiteralPath $playerPath -PathType Leaf)) {
            throw "Godot-importable StoryPack copy is missing: $playerPath"
        }
        $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        $playerHash = (Get-FileHash -LiteralPath $playerPath -Algorithm SHA256).Hash
        if ($sourceHash -ne $playerHash) {
            throw "Generated StoryPack copy is stale: $relativeFile"
        }
        continue
    }

    $playerDirectory = Split-Path -Parent $playerPath
    [void](New-Item -ItemType Directory -Path $playerDirectory -Force)
    Copy-Item -LiteralPath $sourcePath -Destination $playerPath -Force
}

if ($Check) {
    Write-Output "PASS: Godot StoryPack copy matches authoritative content"
}
else {
    Write-Output "Generated Godot StoryPack copy at $playerRoot"
}
