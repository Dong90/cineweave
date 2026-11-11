$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$storyPackPath = Join-Path $repoRoot "content\samples\zero-echo\storypack.json"
$mediaPath = Join-Path $repoRoot "content\samples\zero-echo\media\zero-echo.ogv"

& (Join-Path $repoRoot "tools\content\sync_storypacks.ps1") -Check
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$storyPack = Get-Content -LiteralPath $storyPackPath -Encoding UTF8 -Raw | ConvertFrom-Json
if ($storyPack.format_version -ne "0.1") {
    throw "Authoritative StoryPack must use format_version 0.1."
}
if ($storyPack.entry_node_id -ne "signal-intro") {
    throw "Authoritative StoryPack must declare the signal-intro entry."
}
if (@($storyPack.nodes).Count -ne 2) {
    throw "Authoritative StoryPack must contain the clip and end StoryNodes."
}

$stream = [System.IO.File]::OpenRead($mediaPath)
try {
    $header = New-Object byte[] 4
    [void]$stream.Read($header, 0, $header.Length)
}
finally {
    $stream.Dispose()
}
if ([System.Text.Encoding]::ASCII.GetString($header) -ne "OggS") {
    throw "Authoritative test media must be an Ogg container."
}

Write-Output "PASS: authoritative StoryPack and Godot copy are reproducible"
exit 0
