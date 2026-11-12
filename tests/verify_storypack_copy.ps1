$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sampleRoot = Join-Path $repoRoot "content\samples\zero-echo"
$storyPackPath = Join-Path $sampleRoot "storypack.json"
$manifestPath = Join-Path $sampleRoot "media\media-manifest.json"

& (Join-Path $repoRoot "tools\content\sync_storypacks.ps1") -Check

$storyPack = Get-Content -LiteralPath $storyPackPath -Encoding UTF8 -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $manifestPath -Encoding UTF8 -Raw | ConvertFrom-Json
if (
    $manifest.format_version -ne "0.1" -or
    $manifest.generator -ne "tools/media/generate_zero_echo.ps1" -or
    [string]::IsNullOrWhiteSpace($manifest.ffmpeg) -or
    $manifest.ffmpeg_sha256 -notmatch '^[0-9a-f]{64}$' -or
    $manifest.ffprobe_sha256 -notmatch '^[0-9a-f]{64}$' -or
    [string]::IsNullOrWhiteSpace($manifest.encoding.video) -or
    [string]::IsNullOrWhiteSpace($manifest.encoding.audio)
) {
    throw "Media manifest must record the generator, FFmpeg build and encoding parameters."
}
if ($storyPack.format_version -ne "0.1" -or $storyPack.story_id -ne "zero-echo") {
    throw "Authoritative StoryPack must preserve its V0.1 format and stable identity."
}
if ($storyPack.title -ne "零点回声" -or $storyPack.entry_node_id -ne "platform-2357") {
    throw "Authoritative StoryPack must start 《零点回声》 on the 23:57 platform."
}
if (@($storyPack.nodes).Count -ne 8) {
    throw "Authoritative StoryPack must contain five clips, one choice and two endings."
}

$expectedClips = [ordered]@{
    "platform-2357" = @{
        File = "platform-2357.ogv"; Duration = 50; Next = "future-warning"
        KeyCues = @(@{ Start = 9000; End = 12500; Text = "站台时钟：23:57" })
    }
    "future-warning" = @{
        File = "future-warning.ogv"; Duration = 60; Next = "midnight-train-arrives"
        KeyCues = @(@{ Start = 9000; End = 13500; Text = "未知号码：别上零点列车。" })
    }
    "midnight-train-arrives" = @{
        File = "midnight-train-arrives.ogv"; Duration = 55; Next = "platform-decision"
        KeyCues = @(@{ Start = 11500; End = 15500; Text = "零点列车即将进站。" })
    }
    "board-loop-reveal" = @{
        File = "board-loop-reveal.ogv"; Duration = 70; Next = "loop-ending"
        KeyCues = @(@{ Start = 50000; End = 55500; Text = "警告发送者：循环中的你。" })
    }
    "leave-to-0001" = @{
        File = "leave-to-0001.ogv"; Duration = 60; Next = "survivor-ending"
        KeyCues = @(
            @{ Start = 47000; End = 50000; Text = "00:01" },
            @{ Start = 52000; End = 57500; Text = "未知号码：这一次，你做对了。" }
        )
    }
}
$expectedManifestFiles = @($expectedClips.Values | ForEach-Object { $_.File } | Sort-Object)
$actualManifestFiles = @($manifest.clips | ForEach-Object { $_.file } | Sort-Object)
$uniqueManifestFiles = @($actualManifestFiles | Select-Object -Unique)
if (
    $actualManifestFiles.Count -ne $expectedManifestFiles.Count -or
    $uniqueManifestFiles.Count -ne $actualManifestFiles.Count -or
    (Compare-Object -ReferenceObject $expectedManifestFiles -DifferenceObject $actualManifestFiles).Count -ne 0
) {
    throw "Media manifest must contain exactly the five unique formal zero-echo outputs."
}
$nodesById = @{}
foreach ($node in @($storyPack.nodes)) {
    $nodesById[$node.id] = $node
}

foreach ($nodeId in $expectedClips.Keys) {
    $expected = $expectedClips[$nodeId]
    $node = $nodesById[$nodeId]
    if ($null -eq $node -or $node.type -ne "clip" -or $node.next_node_id -ne $expected.Next) {
        throw "Clip '$nodeId' must preserve the approved StoryGraph transition."
    }
    $expectedResourcePath = "res://content/zero-echo/media/$($expected.File)"
    if ($node.media_path -ne $expectedResourcePath) {
        throw "Clip '$nodeId' must reference $expectedResourcePath."
    }
    $previousEnd = -1
    foreach ($cue in @($node.subtitles)) {
        if ([string]::IsNullOrWhiteSpace($cue.text) -or $cue.start_ms -lt $previousEnd -or $cue.end_ms -le $cue.start_ms -or $cue.end_ms -gt ($expected.Duration * 1000)) {
            throw "Clip '$nodeId' has an invalid or overlapping subtitle cue."
        }
        $previousEnd = $cue.end_ms
    }
    if (@($node.subtitles).Count -eq 0) {
        throw "Clip '$nodeId' must contain Simplified Chinese subtitle cues."
    }
    foreach ($expectedCue in $expected.KeyCues) {
        $matchingCues = @($node.subtitles) | Where-Object {
            $_.start_ms -eq $expectedCue.Start -and
            $_.end_ms -eq $expectedCue.End -and
            $_.text -eq $expectedCue.Text
        }
        if (@($matchingCues).Count -ne 1) {
            throw "Clip '$nodeId' must keep key cue '$($expectedCue.Text)' at $($expectedCue.Start)-$($expectedCue.End)ms."
        }
    }

    $mediaPath = Join-Path $sampleRoot "media\$($expected.File)"
    $manifestEntry = @($manifest.clips) | Where-Object { $_.file -eq $expected.File }
    if (@($manifestEntry).Count -ne 1) {
        throw "Media manifest must contain exactly one record for $($expected.File)."
    }
    if (
        $manifestEntry.duration_seconds -ne $expected.Duration -or
        $manifestEntry.width -ne 1280 -or $manifestEntry.height -ne 720 -or
        $manifestEntry.fps -ne "24/1" -or $manifestEntry.video_codec -ne "theora" -or
        $manifestEntry.audio_codec -ne "vorbis" -or $manifestEntry.sample_rate -ne 48000 -or
        $manifestEntry.channels -ne 1
    ) {
        throw "Media manifest contract failed for $($expected.File)."
    }
    if ((Get-Item -LiteralPath $mediaPath).Length -ne $manifestEntry.bytes) {
        throw "Media size drift detected for $($expected.File)."
    }
    $actualHash = (Get-FileHash -LiteralPath $mediaPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $manifestEntry.sha256) {
        throw "Media hash drift detected for $($expected.File)."
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
        throw "$($expected.File) must be an Ogg container."
    }
}

$choiceNode = $nodesById["platform-decision"]
if ($choiceNode.type -ne "choice" -or @($choiceNode.options).Count -ne 2) {
    throw "The platform decision must expose exactly two options."
}
if (
    $choiceNode.options[0].id -ne "board-last-train" -or
    $choiceNode.options[0].target_node_id -ne "board-loop-reveal" -or
    $choiceNode.options[1].id -ne "leave-platform" -or
    $choiceNode.options[1].target_node_id -ne "leave-to-0001"
) {
    throw "The platform decision must preserve both approved V0.1 routes."
}
if ($nodesById["loop-ending"].title -ne "循环仍在继续" -or $nodesById["survivor-ending"].title -ne "幸存者") {
    throw "Both approved ending identities must be preserved."
}

$boardingDuration = 50 + 60 + 55 + 70
$leavingDuration = 50 + 60 + 55 + 60
if ($boardingDuration -lt 180 -or $boardingDuration -gt 300 -or $leavingDuration -lt 180 -or $leavingDuration -gt 300) {
    throw "Every V0.1 route must run for three to five minutes."
}

Write-Output "PASS: authoritative zero-echo StoryPack, formal media and Godot copy are reproducible"
exit 0
