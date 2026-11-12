$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$storyPackPath = Join-Path $repoRoot "content\samples\zero-echo\storypack.json"
$mediaPath = Join-Path $repoRoot "content\samples\zero-echo\media\zero-echo.ogv"

& (Join-Path $repoRoot "tools\content\sync_storypacks.ps1") -Check

$storyPack = Get-Content -LiteralPath $storyPackPath -Encoding UTF8 -Raw | ConvertFrom-Json
if ($storyPack.format_version -ne "0.1") {
    throw "Authoritative StoryPack must use format_version 0.1."
}
if ($storyPack.entry_node_id -ne "signal-intro") {
    throw "Authoritative StoryPack must declare the signal-intro entry."
}
if (@($storyPack.nodes).Count -ne 4) {
    throw "Authoritative StoryPack must contain the intro, choice and two ending StoryNodes."
}

$choiceNode = @($storyPack.nodes) | Where-Object { $_.id -eq "platform-choice" }
if ($null -eq $choiceNode -or $choiceNode.type -ne "choice") {
    throw "Authoritative StoryPack must contain the platform-choice StoryNode."
}
if (@($choiceNode.options).Count -ne 2) {
    throw "The platform choice must expose exactly two options."
}
if (@($choiceNode.options.id) -notcontains "board-last-train" -or @($choiceNode.options.id) -notcontains "leave-platform") {
    throw "The platform choice must preserve the two stable V0.1 option ids."
}

$endingNodes = @($storyPack.nodes) | Where-Object { $_.type -eq "end" }
if (@($endingNodes).Count -ne 2) {
    throw "Authoritative StoryPack must contain exactly two endings."
}
if (@($endingNodes.id) -notcontains "loop-ending" -or @($endingNodes.id) -notcontains "survivor-ending") {
    throw "Authoritative StoryPack must preserve both V0.1 ending ids."
}
if (@($endingNodes | Where-Object { [string]::IsNullOrWhiteSpace($_.title) }).Count -ne 0) {
    throw "Every V0.1 ending must have a player-facing title."
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
