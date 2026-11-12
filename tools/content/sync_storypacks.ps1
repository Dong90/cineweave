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
    "media\zero-echo.ogv",
    "media\platform-2357.ogv",
    "media\future-warning.ogv",
    "media\midnight-train-arrives.ogv",
    "media\board-loop-reveal.ogv",
    "media\leave-to-0001.ogv"
)
$expectedSourceFiles = @(
    $relativeFiles
    "ASSET_SOURCE.md"
    "media\media-manifest.json"
)
$expectedPlayerFiles = @(
    $relativeFiles
    "media\zero-echo.ogv.uid"
    "media\platform-2357.ogv.uid"
    "media\future-warning.ogv.uid"
    "media\midnight-train-arrives.ogv.uid"
    "media\board-loop-reveal.ogv.uid"
    "media\leave-to-0001.ogv.uid"
)

function Assert-ExactFileSet {
    param(
        [Parameter(Mandatory)]
        [string]$Root,
        [Parameter(Mandatory)]
        [string[]]$Expected,
        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "$Label directory is missing: $Root"
    }
    $rootPath = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
    $actual = @(
        Get-ChildItem -LiteralPath $rootPath -File -Recurse |
            ForEach-Object { $_.FullName.Substring($rootPath.Length + 1) } |
            Sort-Object
    )
    $expectedSorted = @($Expected | Sort-Object)
    $missing = @($expectedSorted | Where-Object { $_ -notin $actual })
    $unexpected = @($actual | Where-Object { $_ -notin $expectedSorted })
    if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
        throw "$Label file set drifted. Missing: $($missing -join ', '); unexpected: $($unexpected -join ', ')"
    }
}

Assert-ExactFileSet -Root $sourceRoot -Expected $expectedSourceFiles -Label "Authoritative zero-echo content"

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

Assert-ExactFileSet -Root $playerRoot -Expected $expectedPlayerFiles -Label "Godot zero-echo copy"

if ($Check) {
    Write-Output "PASS: Godot StoryPack copy matches authoritative content"
}
else {
    Write-Output "Generated Godot StoryPack copy at $playerRoot"
}
